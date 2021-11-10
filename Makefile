export CC="ccache gcc"

build: deps submodule kolibri-wheel build/kolibri-reqs/whlmanifest.txt extra-mods build/webworker.js build/py-worker.js build/consumer.js build/index.html

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
kolibri-wheel: build/kolibri-0.15.0b1.dev0+git.15.gc3238a85-py2.py3-none-any.whl
build/kolibri-%.whl:
	cd kolibri && pipenv --python 3
	cd kolibri && git reset --hard HEAD
	cat kolibri-disable-logging.py >> kolibri/kolibri/deployment/default/settings/base.py
	sed -i -e 's/inline = False/inline = True/' kolibri/kolibri/core/webpack/hooks.py
	echo KOLIBRI_RUN_MODE=dev > kolibri/.env
	cd kolibri && pipenv run pip install -r requirements.txt --upgrade
	cd kolibri && pipenv run pip install -r requirements/dev.txt --upgrade 
	cd kolibri && pipenv run pip install -r requirements/build.txt --upgrade
	cd kolibri && pipenv run nodeenv -p --node=10.24.1
	cd kolibri && pipenv run npm install -g yarn
	cd kolibri && pipenv run yarn install
	cd kolibri && pipenv run yarn run build
	cd kolibri && pipenv run make preseeddb
	cd kolibri && python3 setup.py bdist_wheel
	mkdir -p build
	cp kolibri/dist/$(@F) $@

build/kolibri-reqs/base.txt:
	mkdir -p $(@D)
	cp kolibri/requirements/base.txt $(@D)/_base.txt
	# remove deps that we provide patched versions of
	sed \
		-e '/configobj==/d' \
		$(@D)/_base.txt > $@

build/kolibri-reqs/whlmanifest.txt: build/kolibri-reqs/base.txt patched-kolibri-reqs
	cd $(@D) && pip3 download -d . -r base.txt
	cd $(@D) && ls *.whl > _whlmanifest.txt
	# remove deps that are in the pyodide library
	sed -i \
		-e '/^six-/d' \
		-e '/^more_itertools-/d' \
		-e '/^pytz-/d' \
		-e '/^html5lib-/d' \
		-e '/^python-dateutil-/d' \
		-e '/^webencodings-/d' \
		$(@D)/_whlmanifest.txt
	# move le_utils to end of file, because it needs to be loaded after
	# pycountry
	sed -i -n \
		'/le_utils/H;//!p;$$x;$$s/.//p' \
		$(@D)/_whlmanifest.txt
	# move requests to top of file, because it has a specific urllib3
	# requirement to satisfy (before another dep brings in the latest version)
	sed \
		-e '1,\|requests-|{1{h;d};//!{H;d};G}' \
		$(@D)/_whlmanifest.txt > $@

patched-kolibri-reqs: \
build/kolibri-reqs/django-ipware-1.1.6-py3-none-any.whl \
build/kolibri-reqs/configobj-5.1.0.dev0-py2.py3-none-any.whl \
build/kolibri-reqs/validate-1.1.0.dev0-py2.py3-none-any.whl \
build/kolibri-reqs/future-0.16.0-py3-none-any.whl \
build/kolibri-reqs/le_utils-0.1.34-py3-none-any.whl \
build/kolibri-reqs/pycountry-17.5.14-py3-none-any.whl

# Kolibri depends on le-utils==0.1.34
# There is no wheel on pypi, build one here
build/kolibri-reqs/le_utils-0.1.34-py3-none-any.whl:
	pip3 download -d . --no-deps le-utils==0.1.34
	tar -xf le-utils-0.1.34.tar.gz
	cd le-utils-0.1.34 && python3 setup.py bdist_wheel
	cp le-utils-0.1.34/dist/le_utils-0.1.34-py3-none-any.whl $@

# le-utils depends on pycountry==17.5.14
# There is no wheel on pypi, build one here
build/kolibri-reqs/pycountry-17.5.14-py3-none-any.whl:
	pip3 download -d . --no-deps pycountry==17.5.14
	tar -xf pycountry-17.5.14.tar.gz
	cd pycountry-17.5.14 && python3 setup.py bdist_wheel
	cp pycountry-17.5.14/dist/pycountry-17.5.14-py3-none-any.whl $@

# morango depends on future==0.16.0
# There is no wheel on pypi, build one here
build/kolibri-reqs/future-0.16.0-py3-none-any.whl:
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
build/kolibri-reqs/django-ipware-1.1.6-py3-none-any.whl:
	pip3 download --no-binary :all: --no-deps -d . django-ipware==1.1.6
	tar -xf django-ipware-1.1.6.tar.gz
	cd django-ipware-1.1.6 && python3 setup.py bdist_wheel
	cp django-ipware-1.1.6/dist/django_ipware-1.1.6-py3-none-any.whl $@

# Kolibri depends on configobj, pypi version doesn't have a wheel and doesn't
# use setuptools.
# git version uses setuptools, build our own wheel.
build/kolibri-reqs/configobj-5.1.0.dev0-py2.py3-none-any.whl:
	cd configobj && python3 setup.py bdist_wheel
	cp configobj/dist/configobj-5.1.0.dev0-py2.py3-none-any.whl $@

# configobj also provides the validate module, also needed by Kolibri
build/kolibri-reqs/validate-1.1.0.dev0-py2.py3-none-any.whl:
	cd configobj && PYTHONPATH=src python3 setup_validate.py bdist_wheel
	cp configobj/dist/validate-1.1.0.dev0-py2.py3-none-any.whl $@

build/webworker.js build/py-worker.js build/consumer.js build/index.html: build/%: %
	cp $< $@

extra-mods:
	mkdir -p build/extra-mods
	cp extra-modules/sqlalchemy.data extra-modules/sqlalchemy.js build/extra-mods

clean:
	rm -rf pycountry-17.5.14*
	rm -rf le-utils-0.1.34*
	rm -rf future-0.16.0 future-0.16.0.tar.gz
	rm -rf django-ipware-1.1.6 django-ipware-1.1.6.tar.gz
	rm -rf build
	cd kolibri && pipenv --rm || :
	git submodule foreach git clean -x -d -f

serve:
	cd build && python3 -m http.server
