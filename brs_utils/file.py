"""
Created on June 16 2020

@author: Joan Hérisson
"""

from os import (
    makedirs,
    remove,
    path as os_path,
    walk,
    stat as os_stat
)
from requests import get as r_get
from tempfile import (
    NamedTemporaryFile,
    mkdtemp
)
from tarfile  import open as tf_open
from gzip     import (
    open        as gz_open,
    decompress  as gz_decompress
)
from shutil import (
    copyfileobj,
    rmtree,
    chown
)
from ast import literal_eval
from typing import (
    Dict
)
from logging import (
    Logger,
    getLogger
)
from hashlib import sha512
from pathlib import Path


def check_file_size(
    filename: str,
    size: int,
    logger: Logger = getLogger(__name__)
) -> bool:
    logger.debug('file: {fname}'.format(fname=filename))
    logger.debug('-- SIZE')
    s = os_stat(filename).st_size
    logger.debug('computed: {size}'.format(size=s))
    logger.debug('stored: {size}'.format(size=size))
    logger.debug('--')
    return s == size


def check_sha(
    filename: str,
    sum: str,
    logger: Logger = getLogger(__name__)
) -> bool:

    return sum == sha512(
        Path(filename).read_bytes()
    ).hexdigest()


def chown_r(
    path: str,
    user,
    group = -1,
    logger: Logger = getLogger(__name__)
):
    """
    Recursively belongs path folder to uid:gid.

    Parameters
    ----------
    path: str
        Path to the folder to own.
    uid: int
        User ID.
    gid: int
        Group ID.
    """
    try:
        for dirpath, dirnames, filenames in walk(path):
            chown(dirpath, user, group)
            for filename in filenames:
                chown(os_path.join(dirpath, filename), user)
    except Exception as e:
        logger.error(e)


def download(
    url: str,
    file: str = ""
) -> str:
    """
    Download a file from 'url' and save it as 'file'.

    Parameters:
    url  -- URL the file is downloaded from
    file -- (Optional) filename the downloaded file is saved into (default: "")

    Returns:
    A filename where the downloaded file has stored into
    """
    r = r_get(url)
    if not file:
        f = NamedTemporaryFile(
            mode='wb',
            delete=False
        )
        file = f.name
    else:
        f = open(file, 'wb')
    f.write(r.content)
    f.close()
    return file


def extract_tar_gz(
      file: str,
       dir: str,
    member: str = '',
    delete: bool = False
) -> None:
    if not dir:
        dir = mkdtemp()
    if not os_path.exists(dir):
        makedirs(dir, exist_ok=True)
    tar = tf_open(file, mode='r:gz')
    if member == '':
        tar.extractall(dir)
    else:
        tar.extract(member, dir)
    tar.close()
    if delete:
        rmtree(dir)
    return dir


def compress_tar_gz(
       path:  str,
    outFile:  str = '',
     delete: bool = False
) -> str:
    """
    Compress 'path' into tar.gz format.

    Parameters:
    path    -- file or folder to compress
    outFile -- (Optional) path of compressed file (default: ""), otherwise file is compressed in place
    delete  -- (Optional) the original path is deleted after compression (default: False)

    Returns:
    The archive filename
    """
    if not outFile:
        f = NamedTemporaryFile(
            mode='wb',
            delete=False
        )
        outFile = f.name
    else:
        f = open(outFile, 'wb')
    with tf_open(fileobj=f, mode='w:gz') as tar:
        tar.add(
            path,
            arcname = os_path.basename(path)
        )
        tar.close()
    if delete:
        if os_path.isfile(path):
            remove(path)
        else:
            rmtree(path)
    return outFile


def compress_gz(
     inFile:  str,
    outFile:  str = '',
     delete: bool = False
) -> str:
    """
    Compress 'inFile' into gzip format.

    Parameters:
    inFile  -- file to compress
    outFile -- (Optional) path of compressed file (default: ""), otherwise file is compressed in place
    delete  -- (Optional) the original path is deleted after compression (default: False)

    Returns:
    The archive filename
    """
    if not outFile:
        outFile = inFile+'.gz'
    with open(inFile, 'rb') as f_in, gz_open(outFile, 'wb') as f_out:
        f_out.writelines(f_in)
        f_in.close()
        f_out.close()
    if delete:
        remove(inFile)

    return outFile


def extract_gz_to_string(filename: str) -> str:
    gz = gz_open(filename, mode='rb')
    decode = gz.read().decode()
    gz.close()
    return decode


def extract_gz(
    file: str,
    path: str
) -> str:
    outfile = os_path.join(path, os_path.basename(file[:-3]))
    makedirs(path, exist_ok=True)
    with gz_open(file, 'rb') as f_in, open(outfile, 'wb') as f_out:
        copyfileobj(f_in, f_out)
        f_in.close()
        f_out.close()
    return outfile


def download_and_extract_tar_gz(
    url: str,
    dir: str,
    member: str = ''
) -> None:
    filename = download(url)
    extract_tar_gz(filename, dir, member)
    remove(filename)



def download_and_extract_gz(
    url: str,
    path: str
) -> None:
    filename = download(url)
    extract_gz(filename, path)
    remove(filename)


def file_length(filename: str) -> int:
    with open(filename, 'rb') as f:
        n = sum(1 for line in f)
        f.close()
    return n


def read_dict(filename: str) -> Dict:
    d = {}
    with open(filename, 'r') as f:
        s = f.read()
        f.close()
        d = literal_eval(s)
    return d
