import os


class Config:
    PATH_SHARED = os.getenv("PATH_SHARED", "/shared")
    """The absolute path pointing to the shared folder. The shared folder contains 
    files such as BOFs, BOTs and downloads. """

    PATH_BOFS = os.path.join(PATH_SHARED, "bofs")
    """The absolute path to the folder that contains the BOFs."""

    PATH_CUSTOM_TASKS = os.path.join(PATH_SHARED, "tasks")
    """The absolute path to the folder that contains the custom tasks."""

    PATH_PUBLIC_LIB = os.getenv("PATH_PUBLIC_LIB", "/ost_lib/outflank_stage1")
    """The absolute path pointing to this public Python Stage1 library."""

    URL_API = os.getenv("URL_API", "http://api")
    """The URL where the API is hosted."""

    URL_CHANNEL_SERVICE = os.getenv("URL_CHANNEL_SERVICE", "http://channel_service")
    """The URL where the channel_service API is hosted."""
