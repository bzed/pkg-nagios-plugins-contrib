#!/usr/bin/python
# -*- coding: utf-8 -*-

import sys
import os
import re
from debian import deb822

ALLOWED_FIELDS = ('Suggests',
                  'Recommends',
                  'Depends',
                  'Uploaders',
                  'Version',
                  'Homepage',
                  'Watch',
                  'Description',
                  'Build-Depends')

# find all plugins
__basedir__ = os.path.realpath(os.path.dirname(sys.argv[0]) + os.path.sep + '..')
__plugins__ = [p for p in os.listdir(__basedir__) 
                   if (os.path.isdir(__basedir__ + os.path.sep + p) and p!='debian' and p!='.git' and p!='.pc')]
__plugins__.sort()


__uploaders_re__ = re.compile(r', *')
__shlibs_re__ = re.compile(r'shlibs:Depends=(.+)')

def __get_control_data__():
    # returns (plug, parsed control field data)
    # We look at the first paragraph only!
    for plugin in __plugins__:
        data=(plugin, [x for x in deb822.Packages.iter_paragraphs(file(__basedir__ + os.path.sep+ plugin + os.path.sep + 'control'))][0])
        for key in data[1].iterkeys():
            if key not in ALLOWED_FIELDS:
                raise Exception("Unknown control field in plugin %s: %s" %(data[0],key))
        yield data

def generate_debian_readme_plugins():
    plugins_depends={}
    for plugin, _control in __get_control_data__():
        plugins_depends[plugin]={}
        # look trough keys we might want to merge
        for key in ['Suggests', 'Recommends']:
            if _control.has_key(key):
                plugins_depends[plugin][key]=deb822.PkgRelation.parse_relations(_control[key])

        # check for generated substvars files
        substvarsfile = __basedir__ + os.path.sep + 'debian' + os.path.sep + plugin + os.path.sep + 'substvars'
        if os.path.exists(substvarsfile):
            with open(substvarsfile, 'r') as fd:
                substvars = fd.read()
            try:
                rel = deb822.PkgRelation.parse_relations(__shlibs_re__.findall(substvars)[0])
                if plugins_depends[plugin].has_key('Recommends'):
                    plugins_depends[plugin]['Recommends'].extend(rel)
                else:
                    plugins_depends[plugin]['Recommends']=rel
            except IndexError:
                pass

    # generate content
    result=[]
    for plugin in __plugins__:
        if len(plugins_depends[plugin]) > 0:
            rtext = '%s:' %(plugin,)
            if plugins_depends[plugin].has_key('Recommends'):
                rtext = '%s\n    Required Packages: %s' %(
                    rtext,
                    deb822.PkgRelation.str(plugins_depends[plugin]['Recommends'])
                )
            if plugins_depends[plugin].has_key('Suggests'):
                rtext = '%s\n    Optional Packages: %s' %(
                    rtext,
                    deb822.PkgRelation.str(plugins_depends[plugin]['Suggests'])
                )
            result.append(rtext)
    
    readmefile=__basedir__ + os.path.sep + 'debian' + os.path.sep + 'README.Debian.plugins'
    with open(readmefile + '.in', 'r') as fd:
        readme=fd.read()
    
    readme=readme.replace('#AUTO_UPDATE_README#', '\n\n'.join(result))

    with open(readmefile, 'w') as fd:
        fd.write(readme)

        

def update_control():
    control_data = {
        'Suggests' : [],
        'Recommends' : [],
        'Build-Depends' : [],
        'Description' : [],
        'Uploaders' : []
    }

    for plugin, _control in __get_control_data__():
        # look trough keys we might want to merge
        if _control.has_key('Depends'):
            print "Don't use 'Depends' in %s/control - use 'Recommends' instead" %(plugin,)
            sys.exit(1)
        for key in ['Build-Depends', 'Suggests', 'Recommends']:
            if _control.has_key(key):
                for rel in deb822.PkgRelation.parse_relations(_control[key]):
                    if not rel in control_data[key]:
                        control_data[key].append(rel)
        # extract description
        description = '   * %s' %(plugin,)
        if _control.has_key('Version'):
            description = '%s (%s)' %(description, _control['Version'])
        try:
            description = '%s: %s' %(description, _control['Description'].replace('\n','\n    '))
        except KeyError:
            print 'Description for plugin %s missing!' %(plugin,)
            sys.exit(1)

        try:
            for uploader in __uploaders_re__.split(_control['Uploaders']):
                if uploader not in control_data['Uploaders']:
                    control_data['Uploaders'].append(uploader)
        except KeyError:
            'Uploaders for plugin %s missing!' %(plugin,)
            sys.exit(1)

# disables right now. do we want to have the homepage in the description?
#        if _control.has_key('Homepage'):
#            description = '%s\n     Homepage: %s' %(description, _control['Homepage'])

        control_data['Description'].append(description)


    with open(__basedir__ + os.path.sep + 'debian' + os.path.sep + 'control.in', 'r') as f:
        control_in = f.read()

    for k, v in control_data.iteritems():
        if k == 'Description':
            control_in = control_in.replace('#AUTO_UPDATE_Description#', u'\n'.join(v))
        elif k == 'Uploaders':
            control_in = control_in.replace('#AUTO_UPDATE_Uploaders#', u', '.join(v))
        else:
            control_in = control_in.replace('#AUTO_UPDATE_%s#' %(k, ), deb822.PkgRelation.str(v))

    with open(__basedir__ + os.path.sep + 'debian' + os.path.sep + 'control', 'w') as f:
        f.write(control_in)




def update_copyright():

    copyrights = []
    for plugin, _control in __get_control_data__():
        _p_copyright = '%s:\n\n' %(plugin,)
        if _control.has_key('Homepage'):
            _p_copyright = '%sThe plugin was downloaded from: \n%s\n\n' %(_p_copyright, _control['Homepage'])

        try:
            with open(__basedir__ + os.path.sep + plugin + os.path.sep + 'copyright', 'r') as f:
                _p_copyright = '%s  %s' %(_p_copyright, f.read().decode('utf-8').replace('\n','\n  '))
        except IOError:
            print 'copyright file for plugin %s missing!' %(plugin,)
            sys.exit(1)

        copyrights.append(_p_copyright)

    with open(__basedir__ + os.path.sep + 'debian' + os.path.sep + 'copyright.in', 'r') as f:
        copyright_in = f.read().decode('utf-8')

    copyright_in = copyright_in.replace('#AUTO_UPDATE_Copyright#', u'\n\n------------------------------------------------------------------------------\n\n'.join(copyrights))

    with open(__basedir__ + os.path.sep + 'debian' + os.path.sep + 'copyright', 'w') as f:
        f.write(copyright_in.encode('utf-8'))


def watch():

    import apt_pkg
    apt_pkg.init_system()

    import hashlib

    import urllib2
    url_opener = urllib2.build_opener()
    url_opener.addheaders = [('User-agent', 'Debian nagios-plugins-contrib 1.0')]

    watch_re = re.compile(r'([^ ]+) (.+)')
    whitespace_re = re.compile(r'\s')
    for plugin, _control in __get_control_data__():
        if not _control.has_key('Watch'):
            print 'WARNING: %s - missing watch information!' %(plugin,)
            continue
        try:
            url, check = watch_re.findall(_control['Watch'])[0]
        except IndexError:
            print 'WARNING: %s - failed to parse Watch line!' %(plugin,)
            continue
        try:
            f=url_opener.open(url)
            content = f.read()
            f.close()
        except IOError:
            print 'WARNING: %s - failed to retrieve %s !' %(plugin,url)
            continue
        check=check.strip()
        if check.startswith('SHA1:'):
            check=check.replace('SHA1:','')
            new_sha=hashlib.sha1(content).hexdigest()
            if check != new_sha:
                print 'UPDATE NECESSARY: %s - SHA1 checksum does not match! New checksum: %s' %(plugin,new_sha)
            else:
                print 'OK: %s' %(plugin,)
        else:
            if not _control.has_key('Version'):
                print 'WARNING: %s - missing current version information!' %(plugin,)
                continue
            check_re=re.compile(check)
            # check for simple matches
            found_versions=check_re.findall(content)
            # now also see if the regexp author added too many .* parts and the match is a bit buggy
            # we replace all whitespaces with \n and try again.
            for v in check_re.findall(whitespace_re.sub('\n',content)):
                if not v in found_versions:
                    found_versions.append(v)
            if not found_versions:
                print "WARNING: %s - regex does not match!" %(plugin)
                continue

            new_version = found_versions[0]
            for v in found_versions:
                if (apt_pkg.version_compare(v, found_versions[0]) > 0):
                    new_version = v
            if (apt_pkg.version_compare(new_version, _control['Version'].strip()) > 0):
                print 'UPDATE NECESSARY: %s - found new version %s' %(plugin, new_version)
            elif (apt_pkg.version_compare(new_version, _control['Version'].strip()) < 0):
                print 'WARNING: %s - could not find the current version (found: %s, control says: %s)!' %(plugin, new_version, _control['Version'])
            else:
                print 'OK: %s' %(plugin,)



if __name__ == '__main__':
    from optparse import OptionParser
    prog = os.path.basename(sys.argv[0])
    usage = ('%s [--copyright] [--control] [--watch] [--generate-readme] [-h|--help]') %(prog,)
    parser = OptionParser(usage=usage)

    parser.add_option(
        '--copyright',
        dest='copyright',
        action='store_true',
        default=False,
        help='Update debian/copyright'
    )

    parser.add_option(
        '--control',
        dest='control',
        action='store_true',
        default=False,
        help='Update debian/control'
    )

    parser.add_option(
        '--watch',
        dest='watch',
        action='store_true',
        default=False,
        help='Search for updates'
    )
    parser.add_option(
        '--generate-readme',
        dest='generate_readme',
        action='store_true',
        default=False,
        help='Generate debian/README.Debian.plugins'
    )
    (options, args) = parser.parse_args()

    if not (options.control or options.copyright or options.watch or options.generate_readme):
        parser.print_help()
        sys.exit(1)

    if options.control:
        update_control()

    if options.copyright:
        update_copyright()

    if options.watch:
        watch()

    if options.generate_readme:
        generate_debian_readme_plugins()
