#!/bin/bash

. "${SOURCE_ROOT}/Build/Post-archive-exports.txt"

# Directory created during the Changes-and-Notes.sh stage
VIENNA_UPLOADS_DIR="${SOURCE_ROOT}/Build/Uploads"
GITHUB_REPO="https://github.com/ViennaRSS/vienna-rss"
GITHUB_RELEASE_URL="${GITHUB_REPO}/releases/tag/v%2F${N_VCS_TAG}"
SOURCEFORGE_ASSETS_URL="https://downloads.sourceforge.net/project/vienna-rss/v_${N_VCS_TAG}"

DMG_FILENAME="Vienna${N_VCS_TAG}.dmg"
dSYM_FILENAME="Vienna${N_VCS_TAG}.${VCS_SHORT_HASH}-dSYM"

case "${N_VCS_TAG}" in
	*_beta*)
		VIENNA_CHANGELOG="changelog_beta.xml"
	;;
	*_rc*)
		VIENNA_CHANGELOG="changelog_rc.xml"
	;;
	*)
		VIENNA_CHANGELOG="changelog.xml"
	;;
esac

pushd "${VIENNA_UPLOADS_DIR}"

mv "${PROJECT_DERIVED_FILE_DIR}/Vienna${N_VCS_TAG}.dmg" .

# Make the dSYM Bundle
tar -c -f "${dSYM_FILENAME}.tgz" --format ustar --gzip --no-xattrs --exclude '.DS_Store' -C "$ARCHIVE_DSYMS_PATH" .

# Output the sparkle change log
SPARKLE_BIN=$(find "${HOME}/Library/Developer/Xcode/DerivedData" -regex "${HOME}/Library/Developer/Xcode/DerivedData/${PROJECT}-.*/SourcePackages/artifacts/sparkle/Sparkle/bin")

if [ ! -d "$SPARKLE_BIN" ]; then
	printf 'Unable to locate Sparkle binaries in DerivedData. ' 1>&2
	printf 'Resolve the Swift Packages in Xcode first.\n' 1>&2
	exit 1
fi

export PATH="$SPARKLE_BIN:$PATH"

# Generate EdDSA signature. This command outputs a string of attributes for the
# appcast feed, e.g. sparkle:edSignature="<signature>" length="<length>"
if [ ! -f "$PRIVATE_EDDSA_KEY_PATH" ]; then
	printf 'Unable to load signing private key vienna_private_eddsa_key.pem. Set PRIVATE_EDDSA_KEY_PATH in Scripts/Resources/CS-ID.xcconfig\n' 1>&2
	exit 1
fi
ED_SIGNATURE_AND_LENGTH="$(sign_update "$DMG_FILENAME" -f "$PRIVATE_EDDSA_KEY_PATH")"

pubDate="$(LC_ALL=en_US.UTF8 TZ=GMT date -jf '%FT%TZ' "${VCS_DATE}" '+%a, %d %b %G %T %z')"

cat > "${VIENNA_CHANGELOG}" << EOF
<?xml version="1.0" encoding="UTF-8" ?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
	<channel>
		<title>Vienna Changelog</title>
		<link>https://www.vienna-rss.com/</link>
		<description>Vienna Changelog</description>
		<language>en-us</language>
		<copyright>Copyright 2010-2025, Steve Palmer and contributors</copyright>
		<item>
			<title>Vienna ${V_VCS_TAG} :${VCS_SHORT_HASH}:</title>
			<pubDate>${pubDate}</pubDate>
			<link>${GITHUB_RELEASE_URL}</link>
			<sparkle:version>${N_VCS_NUM}</sparkle:version>
			<sparkle:shortVersionString>${V_VCS_TAG} :${VCS_SHORT_HASH}:</sparkle:shortVersionString>
			<sparkle:minimumSystemVersion>${MACOSX_DEPLOYMENT_TARGET}.0</sparkle:minimumSystemVersion>
			<enclosure url="${SOURCEFORGE_ASSETS_URL}/${DMG_FILENAME}" $ED_SIGNATURE_AND_LENGTH type="application/octet-stream" />
			<sparkle:releaseNotesLink>https://www.vienna-rss.com/sparkle-files/noteson${N_VCS_TAG}.html</sparkle:releaseNotesLink>
		</item>
		<item>
			<title>Vienna 3.8.8 :de36b0c7:</title>
			<pubDate>Sun, 09 Jul 2023 16:33:59 +0000</pubDate>
			<link>https://github.com/ViennaRSS/vienna-rss/releases/tag/v%2F3.8.8</link>
			<sparkle:version>8052</sparkle:version>
			<sparkle:shortVersionString>3.8.8 :de36b0c7:</sparkle:shortVersionString>
			<sparkle:minimumSystemVersion>10.12.0</sparkle:minimumSystemVersion>
			<enclosure url="https://downloads.sourceforge.net/project/vienna-rss/v_3.8.8/Vienna3.8.8.tgz" sparkle:edSignature="FtnUx6IQRQeu8ngmI7WGXyy+Xr6XeFkPLW6V3PjYoPjNaS/yGWqGbWN/okl1bjTOdBph++lr1G2iaYm8Kr55DA==" length="13059409" sparkle:dsaSignature="MC4CFQCvuFjsi/J1Sww++hm8v3VuxoieQwIVAJr0U3qeZd8e1TGAEJf14YK5ooqo" type="application/octet-stream" />
			<sparkle:releaseNotesLink>https://www.vienna-rss.com/sparkle-files/noteson3.8.8.html</sparkle:releaseNotesLink>
		</item>
		<item>
			<title>Vienna 3.7.5 :e811b5c2:</title>
			<pubDate>Sun, 28 Aug 2022 09:13:53 +0000</pubDate>
			<link>https://github.com/ViennaRSS/vienna-rss/releases/tag/v%2F3.7.5</link>
			<sparkle:version>7567</sparkle:version>
			<sparkle:shortVersionString>3.7.5 :e811b5c2:</sparkle:shortVersionString>
			<sparkle:minimumSystemVersion>10.11.0</sparkle:minimumSystemVersion>
			<enclosure url="https://downloads.sourceforge.net/project/vienna-rss/v_3.7.5/Vienna3.7.5.tar.gz" sparkle:edSignature="PQA4qGIXEuK940Euet9AoAwtfxqWF5Tcy2+OXpR6GXJOtdQqBUBpUW89mYyt0ZnGCeOkmOsPPKqdut8Bx0BbBw==" length="12255682" sparkle:dsaSignature="MC0CFQCJch8FBCevZenZOdWaZWf37YTeCwIUM3dnyQz/93FsxPDjBn5e1fsnRsA=" type="application/octet-stream" />
			<sparkle:releaseNotesLink>https://www.vienna-rss.com/sparkle-files/noteson3.7.5.html</sparkle:releaseNotesLink>
		</item>
		<item>
			<title>Vienna 3.5.10 :9b26c77b:</title>
			<pubDate>Sun, 08 Nov 2020 11:58:56 +0000</pubDate>
			<link>https://github.com/ViennaRSS/vienna-rss/releases/tag/v%2F3.5.10</link>
			<sparkle:minimumSystemVersion>10.9.0</sparkle:minimumSystemVersion>
			<enclosure url="https://downloads.sourceforge.net/project/vienna-rss/v_3.5.10/Vienna3.5.10.tar.gz" sparkle:version="7242" sparkle:shortVersionString="3.5.10 :9b26c77b:" length="10865553" sparkle:dsaSignature="MC0CFBzSvYoQZY1XdUjXiEAHKYhhohx+AhUA3DEPV5r1/ZqTJvo5QJ97c3Au/5k=" type="application/octet-stream"/>
			<sparkle:releaseNotesLink>https://www.vienna-rss.com/sparkle-files/noteson3.5.10.html</sparkle:releaseNotesLink>
		</item>
		<item>
			<title>Vienna 3.1.16 :891d05ea:</title>
			<pubDate>Mon, 25 Sep 2017 22:08:32 +0000</pubDate>
			<link>https://github.com/ViennaRSS/vienna-rss/releases/tag/v%2F3.1.16</link>
			<sparkle:minimumSystemVersion>10.8.0</sparkle:minimumSystemVersion>
			<enclosure url="https://downloads.sourceforge.net/project/vienna-rss/v_3.1.16/Vienna3.1.16.tar.gz" sparkle:version="6187" sparkle:shortVersionString="3.1.16 :891d05ea:" length="7594470" sparkle:dsaSignature="MCwCFEQd1TNnQrBn3O3P5rs1tQCvTqraAhR79VyjOaoNJY52H4ZJYXnxtvKl+w==" type="application/octet-stream"/>
			<sparkle:releaseNotesLink>https://www.vienna-rss.com/sparkle-files/noteson3.1.16.html</sparkle:releaseNotesLink>
		</item>
	</channel>
</rss>

EOF

# hierarchy between final releases, release candidates and betas
if [ -f "${VIENNA_UPLOADS_DIR}/changelog.xml" ]; then
	cp "${VIENNA_UPLOADS_DIR}/changelog.xml" "${VIENNA_UPLOADS_DIR}/changelog_rc.xml"
fi
if [ -f "${VIENNA_UPLOADS_DIR}/changelog_rc.xml" ]; then
	cp "${VIENNA_UPLOADS_DIR}/changelog_rc.xml" "${VIENNA_UPLOADS_DIR}/changelog_beta.xml"
fi

open "${VIENNA_UPLOADS_DIR}"
popd
exit 0
