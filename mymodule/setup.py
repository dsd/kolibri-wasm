import pathlib
from setuptools import setup

# The directory containing this file
HERE = pathlib.Path(__file__).parent

# This call to setup() does all the work
setup(
    name="mymodule",
    version="1.0.0",
    description="Python module for web test",
    packages=["mymodule"],
    include_package_data=True,
)
