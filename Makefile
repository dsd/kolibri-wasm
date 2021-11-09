export CC="ccache gcc"

build: deps submodule kolibri-wheel kolibri-reqs/whlmanifest.txt

deps:
	#sudo apt-get install ccache pkg-config gfortran f2c cmake texinfo

submodule:
	git submodule init
	git submodule update

# Build Kolibri, because there aren't any wheels published for the
# development version, and the standard wheels are painfully large for our
# needs (since they bundle all requirements for python2, C extensions for
# many platforms but not ours, etc).
# 
# Following https://kolibri-dev.readthedocs.io/en/develop/getting_started.html
# don't use the Makefile to build the wheel to keep the size under control.
kolibri-wheel: kolibri/dist/kolibri-0.15.0b1.dev0+git.15.gc3238a85-py2.py3-none-any.whl
kolibri/dist/kolibri-%.whl:
	cd kolibri && pipenv --python 3
	echo KOLIBRI_RUN_MODE=dev > kolibri/.env
	cd kolibri && pipenv run pip install -r requirements.txt --upgrade
	cd kolibri && pipenv run pip install -r requirements/dev.txt --upgrade 
	cd kolibri && pipenv run pip install -r requirements/build.txt --upgrade
	cd kolibri && pipenv run nodeenv -p --node=10.24.1
	cd kolibri && pipenv run npm install -g yarn
	cd kolibri && pipenv run yarn install
	cd kolibri && pipenv run yarn run build
	cd kolibri && python3 setup.py bdist_wheel

kolibri-reqs/base.txt:
	mkdir -p kolibri-reqs
	cp kolibri/requirements/base.txt kolibri-reqs/_base.txt
	# remove deps that we provide patched versions of
	sed \
		-e '/configobj==/d' \
		kolibri-reqs/_base.txt > $@

kolibri-reqs/whlmanifest.txt: kolibri-reqs/base.txt patched-kolibri-reqs
	cd kolibri-reqs && pip3 download -d . -r base.txt
	cd kolibri-reqs && ls *.whl > _whlmanifest.txt
	# remove deps that are in the pyodide library
	sed -i \
		-e '/^six-/d' \
		-e '/^more_itertools-/d' \
		-e '/^pytz-/d' \
		-e '/^html5lib-/d' \
		-e '/^python-dateutil-/d' \
		-e '/^webencodings-/d' \
		kolibri-reqs/_whlmanifest.txt
	# move requests to top of file, because it has a specific urllib3
	# requirement to satisfy (before another dep brings in the latest version)
	sed \
		-e '1,\|requests-|{1{h;d};//!{H;d};G}' \
		kolibri-reqs/_whlmanifest.txt > $@

patched-kolibri-reqs: \
kolibri-reqs/django-ipware-1.1.6-py3-none-any.whl \
kolibri-reqs/configobj-5.1.0.dev0-py2.py3-none-any.whl \
kolibri-reqs/validate-1.1.0.dev0-py2.py3-none-any.whl \
kolibri-reqs/future-0.16.0-py3-none-any.whl

# morango depends on future==0.16.0
# There is no wheel on pypi, build one here
kolibri-reqs/future-0.16.0-py3-none-any.whl:
	pip3 download -d . --no-deps future==0.16.0
	tar -xf future-0.16.0.tar.gz
	cd future-0.16.0 && python3 setup.py bdist_wheel
	cp future-0.16.0/dist/future-0.16.0-py3-none-any.whl $@

# This is a dependency of one of Kolibri's requirements
# It doesn't have a wheel available, build one ourselves
# Also, micropip has an issue where it uses the whl name as the name of the
# package. This package is django-ipware but gets built as django_ipware.
# That seems to be an inconsistent convention that micropip does not support.
# Rename the package appropriately.
kolibri-reqs/django-ipware-1.1.6-py3-none-any.whl:
	pip3 download --no-binary :all: --no-deps -d . django-ipware==1.1.6
	tar -xf django-ipware-1.1.6.tar.gz
	cd django-ipware-1.1.6 && python3 setup.py bdist_wheel
	cp django-ipware-1.1.6/dist/django_ipware-1.1.6-py3-none-any.whl $@

# Kolibri depends on configobj, pypi version doesn't have a wheel and doesn't
# use setuptools.
# git version uses setuptools, build our own wheel.
kolibri-reqs/configobj-5.1.0.dev0-py2.py3-none-any.whl:
	cd configobj && python3 setup.py bdist_wheel
	cp configobj/dist/configobj-5.1.0.dev0-py2.py3-none-any.whl $@

# configobj also provides the validate module, also needed by Kolibri
kolibri-reqs/validate-1.1.0.dev0-py2.py3-none-any.whl:
	cd configobj && python3 setup_validate.py bdist_wheel
	cp configobj/dist/validate-1.1.0.dev0-py2.py3-none-any.whl $@

clean:
	rm -rf future-0.16.0 future-0.16.0.tar.gz
	rm -rf django-ipware-1.1.6 django-ipware-1.1.6.tar.gz
	rm -rf kolibri-reqs/
	cd kolibri && pipenv --rm || :
	git submodule foreach git clean -x -d -f
