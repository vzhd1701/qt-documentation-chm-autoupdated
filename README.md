# qt-documentation-chm-autoupdated
[![Build Status](https://travis-ci.com/vzhd1701/qt-documentation-chm-autoupdated.svg?branch=master)](https://travis-ci.com/vzhd1701/qt-documentation-chm-autoupdated)
[![Qt Docs Version](https://img.shields.io/github/v/release/vzhd1701/qt-documentation-chm-autoupdated?color=%230F&label=Qt%20Docs)](https://github.com/vzhd1701/qt-documentation-chm-autoupdated/releases/latest)

[**Download Qt Documentation CHM 5.14.2**](https://github.com/vzhd1701/qt-documentation-chm-autoupdated/releases/latest)

This repository will be automatically updated after each official Qt release.

## Workflow

The basic idea is to use Travis CI to download latest Qt Docs pre-built in HTML format from the [official SDK repository](https://download.qt.io/online/qtsdkrepository/windows_x86/desktop/) (*_src_doc_examples directories), convert them into CHM project using [qt-documentation-chm](https://github.com/vzhd1701/qt-documentation-chm), compile CHM file with Microsoft® HTML Help Compiler from [HTML Help Workshop](https://docs.microsoft.com/en-us/previous-versions/windows/desktop/htmlhelp/microsoft-html-help-downloads) and upload it as a new release for this repository.

## Helper scripts

### deploy.sh

The main script that does two things:

1. Checks Qt official releases repository to see if there is a new version available and updates the tag for this repository, which triggers the second step.
2. Builds the CHM file from the documentation of the latest official Qt release.

The status of the latest checked version is stored in **version_qt_docs**. If any revisions are required to fix the CHM file itself, an additional revision number will be stored in **version_revision**. Revised version will be tagged as LATEST_QT_VERSION-REVISION_NUMBER.

### get_qt_docs.py

```
usage: get_qt_docs.py [-h] (--latest-version | --docs-latest | --docs VERSION)

optional arguments:
  -h, --help        show this help message and exit
  --latest-version  get latest Qt version number
  --docs-latest     get list of URLs for latest version of Qt documentation archives
  --docs VERSION    get list of URLs for selected version of Qt documentation archives
```
