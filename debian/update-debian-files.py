#!/usr/bin/python

import sys
import os
from debian import deb822

# find all plugins
__basedir__ = os.path.realpath(os.path.dirname(sys.argv[0]) + os.path.sep + '..')
__plugins__ = [p for p in os.listdir(__basedir__) 
                   if (os.path.isdir(__basedir__ + os.path.sep + p) and p!='debian' and p!='.git')]
__plugins__.sort()

def update_control():
    control_data = {
        'Depends' : [],
        'Suggests' : [],
        'Recommends' : [],
        'Build-Depends' : [],
        'Description' : []
    }

    for plugin in __plugins__:
        # We look at the first paragraph only!
        _control = [x for x in deb822.Packages.iter_paragraphs(file(__basedir__ + os.path.sep+ plugin + os.path.sep + 'control'))][0]
        # look trough keys we might want to merge
        for key in ['Depends', 'Build-Depends', 'Suggests', 'Recommends']:
            if _control.has_key(key):
                control_data[key].extend(deb822.PkgRelation.parse_relations(_control[key]))
        # extract description
        description = '   * %s' %(plugin,)
        if _control.has_key('Version'):
            description = '%s (%s)' %(description, _control['Version'])
        description = '%s: %s' %(description, _control['Description'].replace('\n','\n    '))

# disables right now. do we want to have the homepage in the description?
#        if _control.has_key('Homepage'):
#            description = '%s\n     Homepage: %s' %(description, _control['Homepage'])

        control_data['Description'].append(description)


    with open(__basedir__ + os.path.sep + 'debian' + os.path.sep + 'control.in', 'r') as f:
        control_in = f.read()

    for k, v in control_data.iteritems():
        if k == 'Description':
            control_in = control_in.replace('#AUTO_UPDATE_Description#', '\n'.join(v))
        else:
            control_in = control_in.replace('#AUTO_UPDATE_%s#' %(k, ), deb822.PkgRelation.str(v))

    with open(__basedir__ + os.path.sep + 'debian' + os.path.sep + 'control', 'w') as f:
        f.write(control_in)




def update_copyright():

    copyrights = []
    for plugin in __plugins__:
        _p_copyright = '%s:\n\n' %(plugin,)
        # We look at the first paragraph only!
        _control = [x for x in deb822.Packages.iter_paragraphs(file(__basedir__ + os.path.sep+ plugin + os.path.sep + 'control'))][0]
        if _control.has_key('Homepage'):
            _p_copyright = '%sThe plugin was downloaded from: \n%s\n\n' %(_p_copyright, _control['Homepage'])

        with open(__basedir__ + os.path.sep + plugin + os.path.sep + 'copyright', 'r') as f:
            _p_copyright = '%s  %s' %(_p_copyright, f.read().replace('\n','\n  '))

        copyrights.append(_p_copyright)

    with open(__basedir__ + os.path.sep + 'debian' + os.path.sep + 'copyright.in', 'r') as f:
        copyright_in = f.read()

    copyright_in = copyright_in.replace('#AUTO_UPDATE_Copyright#', '\n\n---------------------------------\n\n'.join(copyrights))

    with open(__basedir__ + os.path.sep + 'debian' + os.path.sep + 'copyright', 'w') as f:
        f.write(copyright_in)

if __name__ == '__main__':
    from optparse import OptionParser
    prog = os.path.basename(sys.argv[0])
    usage = ('%s [--copyright] [--control] [-h|--help]') %(prog,)
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

    (options, args) = parser.parse_args()

    if not (options.control or options.copyright):
        parser.print_help()
        sys.exit(1)

    if options.control:
        update_control()
    if options.copyright:
        update_copyright()


