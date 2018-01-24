# Copyright 1999-2017 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI="6"

inherit versionator

if [[ ${PV} == 99999999 ]] ; then
	# live ebuild
	inherit git-r3
	EGIT_REPO_URI="https://github.com/neomutt/neomutt.git"
	EGIT_CHECKOUT_DIR="${WORKDIR}/neomutt-${P}"
	KEYWORDS=""
else
	SRC_URI="https://github.com/${PN}/${PN}/archive/${P}.tar.gz"
	KEYWORDS="~amd64"
fi

DESCRIPTION="Teaching an Old Dog New Tricks"
HOMEPAGE="https://www.neomutt.org/"
IUSE="berkdb crypt debug doc gdbm gnutls gpg idn kerberos libressl lua mbox nls notmuch qdbm sasl selinux slang smime ssl tokyocabinet kyotocabinet lmdb"
SLOT="0"
LICENSE="GPL-2"
CDEPEND="
	app-misc/mime-types
	nls? ( virtual/libintl )

	tokyocabinet? ( dev-db/tokyocabinet )
	qdbm? ( dev-db/qdbm )
	gdbm? ( sys-libs/gdbm )
	berkdb? ( >=sys-libs/db-4:= )
	kyotocabinet? ( dev-db/kyotocabinet )
	lmdb? ( dev-db/lmdb )

	gnutls?  ( >=net-libs/gnutls-1.0.17 )
	!gnutls? (
		ssl? (
			!libressl? ( >=dev-libs/openssl-0.9.6:0 )
			libressl? ( dev-libs/libressl )
		)
	)
	sasl?    ( >=dev-libs/cyrus-sasl-2 )
	kerberos? ( virtual/krb5 )
	idn?     ( net-dns/libidn )
	gpg?     ( >=app-crypt/gpgme-0.9.0 )
	smime?   (
		!libressl? ( >=dev-libs/openssl-0.9.6:0 )
		libressl? ( dev-libs/libressl )
	)
	notmuch? ( net-mail/notmuch )
	slang? ( sys-libs/slang )
	!slang? ( >=sys-libs/ncurses-5.2:0 )
	lua? (
		|| (
			dev-lang/lua:5.2
			dev-lang/lua:5.3
		)
	)
"
DEPEND="${CDEPEND}
	net-mail/mailbase
	doc? (
		dev-libs/libxml2
		dev-libs/libxslt
		app-text/docbook-xsl-stylesheets
		|| ( www-client/lynx www-client/w4m www-client/elinks )
	)"
RDEPEND="${CDEPEND}
	selinux? ( sec-policy/selinux-mutt )
"

# github prefixes with project name
S="${WORKDIR}/neomutt-${P}"

src_prepare() {
	eapply_user
}

		#"$(use_with kerberos gss)"
src_configure() {
	local myconf=(
		"$(use_enable debug)"
		"$(use_enable crypt pgp)"
		"$(use_enable gpg gpgme)"
		"$(use_enable smime)"
		"$(use_enable idn)"
		"$(use_enable lua)"
		"$(use_enable nls)"
		"$(use_enable notmuch)"
		"$(use_enable gdbm)"
		"$(use_enable lmdb)"
		"$(use_enable qdbm)"
		"$(use_enable kyotocabinet)"
		"$(use_enable tokyocabinet)"
		"--sysconfdir=${EPREFIX}/etc/${PN}"
		#"$(use_enable doc)"
		#"$(use_with berkdb bdb)"
		#"--docdir=${EPREFIX}/usr/share/doc/${PN}-${PVR}"
	)

	if [[ ${CHOST} == *-solaris* ]] ; then
		# arrows in index view do not show when using wchar_t
		myconf+=( "--without-wc-funcs" )
	fi

    if use slang; then
		myconf+=( "$(use_with slang ui slang)" )
	fi

    if use lmdb; then
	    local hc_backend="lmdb"
	elif use gdbm; then
	    local hc_backend="gdbm"
	elif use qdbm; then
	    local hc_backend="qdbm"
	elif use kyotocabinet; then
	    local hc_backend="kyotocabinet"
	elif use tokyocabinet; then
	    local hc_backend="tokyocabinet"
	else
	    local hc_backend=""
	fi

	if [ -z $hc_backend ]; then
	    myconf+=( "--$hcbackend")
	fi


	if use gnutls; then
		myconf+=( "--gnutls" )
	elif use ssl; then
		myconf+=( "--ssl" )
	fi

	if use notmuch; then
        myconf+=( "--notmuch" )
	fi

	if use sasl; then
        myconf+=( "--sasl" )
	fi

	if use kerberos; then
	    myconf+=( "--gss" )
	fi

	if use mbox; then
		myconf+=( "--with-mailpath=${EPREFIX}/var/spool/mail" )
	else
		myconf+=(
		  "--homespool"
		  "--with-homespool=Maildir"
		)
	fi

	econf "${myconf[@]}" || die "configure failed"
}

src_install() {
	emake DESTDIR="${D}" install || die "install failed"

	# A man-page is always handy, so fake one
	if use !doc; then
		emake -C doc DESTDIR="${D}" neomuttrc.man || die
		cp doc/neomuttrc.man neomuttrc.5
		doman neomuttrc.5
		# make the fake slightly better, bug #413405
		sed -e 's#@docdir@/manual.txt#http://www.neomutt.org/doc/devel/manual.html#' \
			-e 's#in @docdir@,#at http://www.neomutt.org/,#' \
			-e "s#@sysconfdir@#${EPREFIX}/etc/${PN}#" \
			-e "s#@bindir@#${EPREFIX}/usr/bin#" \
			doc/neomutt.man > neomutt.1
		doman neomutt.1
	fi

	for f in "${ED}"/usr/share/locale/*/LC_MESSAGES/neomutt.mo ; do
		mv "${f}" "${f%/*}/neomutt.mo"
	done

	dodoc COPYRIGHT ChangeLog* README*
}

pkg_postinst () {
	for r in ${REPLACING_VERSIONS}; do
		if [[ $(get_major_version $r) -le 20171006 ]]; then
			elog "Please note that starting with version 20171013, the binaries (as well as"
			elog "the configuration files, man pages etc.) are called \"neomutt\" instead of"
			elog "\"mutt\"."
			break
		fi
	done
}
