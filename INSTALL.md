Installation and configure of the external resources

# Quick Installation (Ubuntu/Fedora)

## Disclamer
UniPrime 1.14 has been updated to support all recent development of the external resources it requires. Here is a quick installation tutorial provided without any warranty. It is base on a standard installation of either [Ubuntu](http://www.ubuntu.com/) 12+ or [Fedora](https://fedoraproject.org/) 17+.

## Primer3
You will need [Primer3](http://primer3.sourceforge.net/)

```
(ubuntu) apt-get install primer3
(fedora) yum install primer3
```

## T-Coffee

Check T-Coffee [installation](http://www.tcoffee.org/Workshops/tcoffeetutorials/installation.html) page for extra details

```
(ubuntu) apt-get install t-coffee
(fedora) yum install t-coffee
```

## Blast
You will need the to download the NCBI Blast+ package from the [NCBI ftp](ftp://ftp.ncbi.nlm.nih.gov/blast/executables/blast+/LATEST/) and install the RPM package for fedora

```
     rpm ncbi-blast-xxxxxxx.rpm
```

or run the installation executable for ubuntu

```
     tar xcfz ncbi-blast-xxx-linux.tar.gz
     cd ncbi-blast-xxx
     sudo cp bin/* /usr/local/bin
```

## UniPrime
Download, then unpack the tar file. For example:

```
     bunzip2 uniprime-1.14.tar.bz2
     tar xvf uniprime-1.14.tar
     cd uniprime-1.14
```

Initialising the Database:

```
     createdb uniprime
     psql uniprime < uniprime.sql
```

This process assumes that you are using a functional postgreSQL server/client and the current user is registered as an SQL user.
Copy the web pages in your web server root (usually `/var/www/html`) and grant the access to the database to the web server user (usually www, www-admin or _www):

```
     sudo cp -r www/uniprime /your_web_server_path
     sudo chown -R www-admin:www-admin /your_web_server_path/uniprime
     sudo ./grant.sh www-admin | psql uniprime
```

then use your web browser to finalise the installation (usually the SERVER-ADDRESS is 127.0.0.1):

```
     http://SERVER-ADDRESS/uniprime/install.php
```

The files you will need (`uniprime.pm` and `UniTools.pm`) are in directory `bin` of the distribution package.