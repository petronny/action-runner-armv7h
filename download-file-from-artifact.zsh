#!/bin/zsh
set -e +x

zparseopts \
	-repo:=repo \
	-workflow:=workflow \
	-file:=file \
	-type:=_type \
	-pkgname:=pkgname \
	-save-path:=_path \
	-save-json:=save_json \
	-use-json:=use_json \

repo=${repo[2]}
workflow=${workflow[2]}
file=${file[2]}
_type=${_type[2]}
pkgname=${pkgname[2]}
_path=${_path[2]}
save_json=${save_json[2]}
use_json=${use_json[2]}

if [ -z "$workflow" ]
then
	url="https://api.github.com/repos/${repo}/actions/artifacts?per_page=100"
else
	url="https://api.github.com/repos/${repo}/actions/runs/${workflow}/artifacts"
fi

curl_args=(-L -sS -H "Accept: application/vnd.github.everest-preview+json" -H "Authorization: token $TOKEN" $url)

if [ -z "$workflow" ]
then
	[ -n "$json" ] && echo "Warning:\tNot saving json if no workflow id is specificed." >> /dev/stderr
	save_json="/dev/null"
fi
[ -z "$save_json" ] && save_json="/dev/null"

artifact_id=$( ([ -z "$use_json" ] && curl ${curl_args} || cat ${use_json}) | tee > $save_json | jq ".artifacts | .[] | select(.name==\"${file}\") | .id" | head -n1)

if [ -z "$artifact_id" ]
then
	echo "Error:\tFile ${file} not found." >> /dev/stderr
	exit 1
fi

if [ -z "$use_json" ]
then
	url="https://api.github.com/repos/$repo/actions/artifacts/$artifact_id/zip"
else
	url=$(cat ${use_json} | jq -r ".artifacts | .[] | select(.id==${artifact_id}) | .archive_download_url" | head -n1)
fi

curl_args=(-L -sS -H "Accept: application/vnd.github.everest-preview+json" -H "Authorization: token $TOKEN" $url)

if [ "$_type" = "file" ]
then
	curl $curl_args | bsdtar -xvf - -O
else
	mkdir -p $_path
	cd $_path

	if [ -z "$pkgname" ]
	then
		curl $curl_args | bsdtar -xvf -
	else
		curl $curl_args -o $pkgbase.zip

		package=$(bsdtar tf ${pkgbase}.zip |
			sed 's/COLON/:/g' |
			grep -P "^${pkgname}-[0-9.:-]*-(x86_64|armv6h|armv7h|aarch64|any)\.pkg\.tar.*" |
			sed 's/:/COLON/g')

		if [ -z "$package" ]
		then
			echo "Error:\tNo package named ${pkgname} found in ${file}." >> /dev/stderr
			exit 2
		fi

		bsdtar xvf ${pkgbase}.zip $package
	fi

	for i in *.pkg.tar*
	do
		if [ $(echo $i | grep COLON -c) -gt 0 ]
		then
			mv $i $(echo $i | sed 's/COLON/:/g')
		fi
	done
fi
