#!/usr/bin/python

import sys
import os

# find all plugins
__plugins__ = [p for p in os.listdir(os.path.realpath(os.path.dirname(sys.argv[0]) + os.path.sep + '..')) 
                   if (os.path.isdir(p) and p!='debian' and p!='.git')]
__plugins__.sort()


def update_control():
    pass

def update_copyright():
    pass

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


