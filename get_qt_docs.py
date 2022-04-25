import argparse
import re
import urllib

import bs4


def get_last_version():
    qt_release_repo = "https://download.qt.io/official_releases/qt/"

    with urllib.request.urlopen(qt_release_repo) as p:
        page = bs4.BeautifulSoup(p.read(), 'html5lib')

    major_version_dir = page.find('table').find_all('tr')[3].find('a').get('href')
    major_version_dir_url = urllib.parse.urljoin(qt_release_repo, major_version_dir)

    with urllib.request.urlopen(major_version_dir_url) as p:
        page = bs4.BeautifulSoup(p.read(), 'html5lib')

    latest_version = page.find('table').find_all('tr')[3].find('a').text[:-1]

    return latest_version

def get_docs_urls(qt_version):
    qt_version_flat = qt_version.replace('.', '')
    qt_version_major = qt_version_flat[0]
    qt_docs_repo_root = f"https://download.qt.io/online/qtsdkrepository/windows_x86/desktop/qt{qt_version_major}_{qt_version_flat}_src_doc_examples"
    qt_docs_repo_xml = f"{qt_docs_repo_root}/Updates.xml"

    try:
        with urllib.request.urlopen(qt_docs_repo_xml) as p:
            page = bs4.BeautifulSoup(p.read(), 'xml')
    except urllib.error.HTTPError as e:
        if e.code == 404:
            raise ValueError(f"Documentation repository XML for Qt v.{qt_version} not found!") from e

    packages = [p.parent for p in page.find_all("Name", text=re.compile("^qt\..*?\.doc(\..*)?$"))]

    docs_urls = []
    for package in packages:
        package_name = package.find("Name").text
        package_version = package.find("Version").text
        package_archives = [p.strip() for p in package.find("DownloadableArchives").text.split(",") if p.strip()]

        for archive_name in package_archives:
            docs_urls.append(f"{qt_docs_repo_root}/{package_name}/{package_version}{archive_name}")

    if not docs_urls:
        raise RuntimeError(f"No documentation archives for Qt v.{qt_version} found!")

    return docs_urls

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument('--latest-version', action='store_true', help="get latest Qt version number")
    group.add_argument('--docs-latest', action='store_true', help="get list of URLs for latest version of Qt documentation archives")
    group.add_argument('--docs', metavar='VERSION', help="get list of URLs for selected version of Qt documentation archives")
    args = vars(parser.parse_args())

    if args['latest_version']:
        print(get_last_version())
    if args['docs_latest']:
        version = get_last_version()
        docs_urls = get_docs_urls(version)

        for url in docs_urls:
            print(url)
    if args['docs']:
        docs_urls = get_docs_urls(args['docs'])

        for url in docs_urls:
            print(url)
