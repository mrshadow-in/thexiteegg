#!/bin/bash
# Forge Installation Script
#
# Server Files: /mnt/server
apt update
apt install -y curl jq
if [[ ! -d /mnt/server ]]; then
mkdir /mnt/server
fi
cd /mnt/server
# Remove spaces from the version number to avoid issues with curl
FORGE_VERSION="$(echo "$FORGE_VERSION" | tr -d ' ')"
MC_VERSION="$(echo "$MC_VERSION" | tr -d ' ')"
if [[ ! -z ${FORGE_VERSION} ]]; then
DOWNLOAD_LINK=https://maven.minecraftforge.net/net/minecraftforge/forge/${FORGE_VERSION}/forge-${FORGE_VERSION}
FORGE_JAR=forge-${FORGE_VERSION}*.jar
else
JSON_DATA=$(curl -sSL https://files.minecraftforge.net/maven/net/minecraftforge/forge/promotions_slim.json)
if [[ "${MC_VERSION}" == "latest" ]] || [[ "${MC_VERSION}" == "" ]]; then
echo -e "getting latest version of forge."
MC_VERSION=$(echo -e ${JSON_DATA} | jq -r '.promos | del(."latest-1.7.10") | del(."1.7.10-latest-1.7.10") | to_entries[] | .key | select(contains("latest")) | split("-")[0]' | sort -t. -k 1,1n -k 2,2n -k 3,3n -k 4,4n | tail -1)
BUILD_TYPE=latest
fi
if [[ "${BUILD_TYPE}" != "recommended" ]] && [[ "${BUILD_TYPE}" != "latest" ]]; then
BUILD_TYPE=recommended
fi
echo -e "minecraft version: ${MC_VERSION}"
echo -e "build type: ${BUILD_TYPE}"
## some variables for getting versions and things
FILE_SITE=https://maven.minecraftforge.net/net/minecraftforge/forge/
VERSION_KEY=$(echo -e ${JSON_DATA} | jq -r --arg MC_VERSION "${MC_VERSION}" --arg BUILD_TYPE "${BUILD_TYPE}" '.promos | del(."latest-1.7.10") | del(."1.7.10-latest-1.7.10") | to_entries[] | .key | select(contains($MC_VERSION)) | select(contains($BUILD_TYPE))')
## locating the forge version
if [[ "${VERSION_KEY}" == "" ]] && [[ "${BUILD_TYPE}" == "recommended" ]]; then
echo -e "dropping back to latest from recommended due to there not being a recommended version of forge for the mc version requested."
VERSION_KEY=$(echo -e ${JSON_DATA} | jq -r --arg MC_VERSION "${MC_VERSION}" '.promos | del(."latest-1.7.10") | del(."1.7.10-latest-1.7.10") | to_entries[] | .key | select(contains($MC_VERSION)) | select(contains("latest"))')
fi
## Error if the mc version set wasn't valid.
if [ "${VERSION_KEY}" == "" ] || [ "${VERSION_KEY}" == "null" ]; then
echo -e "The install failed because there is no valid version of forge for the version of minecraft selected."
exit 1
fi
FORGE_VERSION=$(echo -e ${JSON_DATA} | jq -r --arg VERSION_KEY "$VERSION_KEY" '.promos | .[$VERSION_KEY]')
if [[ "${MC_VERSION}" == "1.7.10" ]] || [[ "${MC_VERSION}" == "1.8.9" ]]; then
DOWNLOAD_LINK=${FILE_SITE}${MC_VERSION}-${FORGE_VERSION}-${MC_VERSION}/forge-${MC_VERSION}-${FORGE_VERSION}-${MC_VERSION}
FORGE_JAR=forge-${MC_VERSION}-${FORGE_VERSION}-${MC_VERSION}.jar
if [[ "${MC_VERSION}" == "1.7.10" ]]; then
FORGE_JAR=forge-${MC_VERSION}-${FORGE_VERSION}-${MC_VERSION}-universal.jar
fi
else
DOWNLOAD_LINK=${FILE_SITE}${MC_VERSION}-${FORGE_VERSION}/forge-${MC_VERSION}-${FORGE_VERSION}
FORGE_JAR=forge-${MC_VERSION}-${FORGE_VERSION}.jar
fi
fi
#Adding .jar when not eding by SERVER_JARFILE
if [[ ! $SERVER_JARFILE = *\.jar ]]; then
SERVER_JARFILE="$SERVER_JARFILE.jar"
fi
#Downloading jars
echo -e "Downloading forge version ${FORGE_VERSION}"
echo -e "Download link is ${DOWNLOAD_LINK}"
if [[ ! -z "${DOWNLOAD_LINK}" ]]; then
if curl --output /dev/null --silent --head --fail ${DOWNLOAD_LINK}-installer.jar; then
echo -e "installer jar download link is valid."
else
echo -e "link is invalid. Exiting now"
exit 2
fi
else
echo -e "no download link provided. Exiting now"
exit 3
fi
curl -s -o installer.jar -sS ${DOWNLOAD_LINK}-installer.jar
#Checking if downloaded jars exist
if [[ ! -f ./installer.jar ]]; then
echo "!!! Error downloading forge version ${FORGE_VERSION} !!!"
exit
fi
function unix_args {
echo -e "Detected Forge 1.17 or newer version. Setting up forge unix args."
ln -sf libraries/net/minecraftforge/forge/*/unix_args.txt unix_args.txt
}
# Delete args to support downgrading/upgrading
rm -rf libraries/net/minecraftforge/forge
rm unix_args.txt
#Installing server
echo -e "Installing forge server.\n"
java -jar installer.jar --installServer || { echo -e "install failed using Forge version ${FORGE_VERSION} and Minecraft version ${MINECRAFT_VERSION}"; exit 4; }
# Check if we need a symlink for 1.17+ Forge JPMS args
if [[ $MC_VERSION =~ ^1\.(17|18|19|20|21|22|23) || $FORGE_VERSION =~ ^1\.(17|18|19|20|21|22|23) ]]; then
unix_args
# Check if someone has set MC to latest but overwrote it with older Forge version, otherwise we would have false positives
elif [[ $MC_VERSION == "latest" && $FORGE_VERSION =~ ^1\.(17|18|19|20|21|22|23) ]]; then
unix_args
else
# For versions below 1.17 that ship with jar
mv $FORGE_JAR $SERVER_JARFILE
fi
echo -e "Deleting installer.jar file.\n"
rm -rf installer.jar
