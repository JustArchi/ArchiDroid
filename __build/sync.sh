#!/bin/bash

#     _             _     _ ____            _     _
#    / \   _ __ ___| |__ (_)  _ \ _ __ ___ (_) __| |
#   / _ \ | '__/ __| '_ \| | | | | '__/ _ \| |/ _` |
#  / ___ \| | | (__| | | | | |_| | | | (_) | | (_| |
# /_/   \_\_|  \___|_| |_|_|____/|_|  \___/|_|\__,_|
#
# Copyright 2014-2015 Łukasz "JustArchi" Domeradzki
# Contact: JustArchi@JustArchi.net
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# This script is used to update repos according to current UPSTREAMs
# It should be used only by repo owners with write access
# Don't bother if you don't have your own repos with upstreams, like android_build

ORIGIN="origin"
TARGET_BRANCH="$1"

REPO_DEPENDS_ON_UPSTREAM() {
	case "$1" in
		"android_"*) return 0 ;;
		"proprietary_"*) return 0 ;;
		"lge-kernel-lproj") return 0 ;;
		"Superuser") return 0 ;;
		*) return 1 ;;
	esac
}

UPDATEREPO() {
	cd "$1" || return 1
	while read BRANCH; do
		if [[ -z "$BRANCH" || "$BRANCH" = "HEAD"* || "$BRANCH" = *"-old" || ( -n "$TARGET_BRANCH" && "$BRANCH" != "$TARGET_BRANCH"* ) ]]; then
			continue
		fi
		git reset --hard >/dev/null 2>&1 # Clean
		git clean -fd >/dev/null 2>&1 # The mess
		git checkout "$BRANCH" >/dev/null 2>&1
		if [[ $? -ne 0 ]]; then
			git reset --hard >/dev/null 2>&1 # Clean
			git clean -fd >/dev/null 2>&1 # The mess
			echo -e "\e[31mFAILED:\e[0m $1 $BRANCH (stage 1)"
			continue
		fi
		git pull "$ORIGIN" "$BRANCH" >/dev/null 2>&1
		if [[ $? -ne 0 ]]; then
			git reset --hard >/dev/null 2>&1 # Clean
			git clean -fd >/dev/null 2>&1 # The mess
			echo -e "\e[31mFAILED:\e[0m $1 $BRANCH (stage 2)"
			continue
		fi
		SUCCESS=1
		if [[ -f "UPSTREAMS" ]]; then
			while read UPSTREAM; do
				UPSTREAM_REPO="$(echo "$UPSTREAM" | awk '{print $1}')"
				UPSTREAM_BRANCH="$(echo "$UPSTREAM" | awk '{print $2}')"
				if [[ -z "$UPSTREAM_BRANCH" ]]; then
					UPSTREAM_BRANCH="$BRANCH"
				fi
				git pull "https://github.com/$UPSTREAM_REPO" "$UPSTREAM_BRANCH" >/dev/null 2>&1
				if [[ $? -ne 0 ]]; then
					SUCCESS=0
					git reset --hard >/dev/null 2>&1 # Clean
					git clean -fd >/dev/null 2>&1 # The mess
					break
				fi
			done < UPSTREAMS
		fi
		if [[ "$SUCCESS" -eq 1 ]]; then
			git push "$ORIGIN" "$BRANCH"
			echo -e "\e[32mSUCCESS:\e[0m $1 $BRANCH"
		else
			echo -e "\e[31mFAILED:\e[0m $1 $BRANCH (stage 3)"
		fi
	done < <(git branch -r | tr -d '*' | tr -d ' ' | cut -d '/' -f 2)
	return 0
}

CHECKREPO() {
	if [[ ! -d "$1" ]] && REPO_DEPENDS_ON_UPSTREAM "$1"; then
		git clone "https://github.com/ArchiDroid/$1" >/dev/null 2>&1
	fi
	if [[ -d "$1/.git" ]]; then
		UPDATEREPO "$1"
	else
		echo "INFO: Not interested in $1"
	fi
}

if ! git config user.email >/dev/null 2>&1; then
	git config --global user.email "JustArchi@JustArchi.net"
	git config --global user.name "JustArchi"
fi

if [[ -f "roomservice.xml" ]]; then
	echo "INFO: Manifest mode!"
	while read REPO; do
		CHECKREPO "$REPO" &
	done < <(grep "project name=\"ArchiDroid/" "roomservice.xml" | cut -d '"' -f 2 | cut -d '/' -f 2 | sort -u)
else
	echo "INFO: Repo mode!"
	while read REPO; do
		CHECKREPO "$REPO" &
	done < <(curl https://api.github.com/users/ArchiDroid/repos?per_page=9999 2>/dev/null | grep "\"name\":" | cut -d '"' -f 4 | sort -u)
fi

wait

exit 0
