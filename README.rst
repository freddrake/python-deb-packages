====================================
Python packaging for Debian & Ubuntu
====================================

The **build-package.sh** script can build .deb packages for a "clean"
Python installation on Debian & Ubuntu machines with the usual required
build environment already installed.  The generated packages produce an
installation that is independent of the "system" Python, without any
3rd-party libraries installed.

This allows creation of application packages built on top of Python
without picking up libraries installed for other purposes on the
system.  Library versions can be managed entirely by applications, and
version conflicts across applications are not an issue.


Generating a package
--------------------

Build a .deb package by downloading the Python sources (use the .xz
compressed tarball) in the **sources** directory, then run::

    $ ./build-package.sh 3.6.5

replacing **3.6.5** with the version number for the Python you want to
build.

The resulting Python installation will be located in
**/opt/cleanpython36** (again, replacing **36** with the major/minor
versions from the version you specified on the command line).
