package Pod::Weaver::PluginBundle::DROLSKY;

use strict;
use warnings;

our $VERSION = '0.43';

use namespace::autoclean -also => ['_exp'];

use Module::Runtime qw( use_module );
use PadWalker qw( peek_sub );
use Pod::Weaver::Config::Assembler;
use Pod::Weaver::Section::Contributors;
use Pod::Weaver::Section::GenerateSection;

sub _exp { Pod::Weaver::Config::Assembler->expand_package( $_[0] ) }

sub configure {
    my $self = shift;

    # this sub behaves somewhat like a Dist::Zilla pluginbundle's configure()
    # -- it returns a list of strings or 1, 2 or 3-element arrayrefs
    # containing plugin specifications. The goal is to make this look as close
    # to what weaver.ini looks like as possible.

    # I wouldn't have to do this ugliness if I could have some configuration values passed in from weaver.ini or
    # the [PodWeaver] plugin's use of config_plugin (where I could define a 'licence' option)
    my $podweaver_plugin
        = ${ peek_sub( \&Dist::Zilla::Plugin::PodWeaver::weaver )->{'$self'}
        };
    my $licence_plugin = $podweaver_plugin
        && $podweaver_plugin->zilla->plugin_named('@Author::DROLSKY/License');
    my $licence_filename
        = $licence_plugin ? $licence_plugin->filename : 'LICENCE';

    return (
        '@CorePrep',
        '-SingleEncoding',
        [ '-Transformer' => List     => { transformer => 'List' } ],
        [ '-Transformer' => Verbatim => { transformer => 'Verbatim' } ],

        [ 'Region' => 'header' ],
        'Name',
        'Version',
        [ 'Region'  => 'prelude' ],
        [ 'Generic' => 'SYNOPSIS' ],
        [ 'Generic' => 'DESCRIPTION' ],
        [ 'Generic' => 'OVERVIEW' ],
        [ 'Collect' => 'ATTRIBUTES' => { command => 'attr' } ],
        [ 'Collect' => 'METHODS' => { command => 'method' } ],
        [ 'Collect' => 'FUNCTIONS' => { command => 'func' } ],
        [ 'Collect' => 'TYPES' => { command => 'type' } ],
        'Leftovers',
        [ 'Region' => 'postlude' ],

        [
            'GenerateSection' => 'generate SUPPORT' => {
                title            => 'SUPPORT',
                main_module_only => 0,
                text             => [
                    <<'SUPPORT',
{{ join("\n\n",
    ($bugtracker_email && $bugtracker_email =~ /rt\.cpan\.org/)
    ? "Bugs may be submitted through L<the RT bug tracker|$bugtracker_web>\n(or L<$bugtracker_email|mailto:$bugtracker_email>)."
    : $bugtracker_web
    ? "bugs may be submitted through L<$bugtracker_web>."
    : (),

    $distmeta->{resources}{x_MailingList} ? 'There is a mailing list available for users of this distribution, at' . "\nL<" . $distmeta->{resources}{x_MailingList} . '>.' : (),

    $distmeta->{resources}{x_IRC}
        ? 'This distrubtion also has an irc channel at' . "\nL<"
            . do {
                # try to extract the channel
                if (my ($network, $channel) = ($distmeta->{resources}{x_IRC} =~ m!(?:://)?(\w+(?:\.\w+)*)/?(#\w+)!)) {
                    'C<' . $channel . '> on C<' . $network . '>|' . $distmeta->{resources}{x_IRC}
                }
                else {
                    $distmeta->{resources}{x_IRC}
                }
            }
            . '>.'
        : (),

    ($distmeta->{x_authority} // '') eq 'cpan:DROLSKY'
    ? "I am also usually active on irc as 'drolsky' on C<irc://irc.perl.org>."
    : (),
) }}
SUPPORT
                ]
            },
        ],

        [
            'AllowOverride' => 'allow override SUPPORT' => {
                header_re      => '^(SUPPORT|BUGS)\b',
                action         => 'prepend',
                match_anywhere => 0,
            },
        ],

        [
            'GenerateSection' => 'generate DONATIONS' => {
                title            => 'DONATIONS',
                main_module_only => 0,
                is_template      => 0,
                text             => [
                    <<'DONATIONS',
If you'd like to thank me for the work I've done on this module, please
consider making a "donation" to me via PayPal. I spend a lot of free time
creating free software, and would appreciate any support you'd care to offer.

Please note that B<I am not suggesting that you must do this> in order for me
to continue working on this particular software. I will continue to do so,
inasmuch as I have in the past, for as long as it interests me.

Similarly, a donation made in this way will probably not make me work on this
software much more, unless I get so many donations that I can consider working
on free software full time (let's all have a chuckle at that together).

To donate, log into PayPal and send money to autarch@urth.org, or use the
button at L<http://www.urth.org/~autarch/fs-donation.html>.
DONATIONS
                ]
            },
        ],

        'Authors',
        [ 'Contributors' => { ':version' => '0.008' } ],
        [
            'Legal' => {
                ':version' => '4.011',
                header     => 'COPYRIGHT AND ' . $licence_filename
            }
        ],
        [ 'Region' => 'footer' ],
    );
}

sub mvp_bundle_config {
    my $self = shift || __PACKAGE__;

    return map { $self->_expand_config($_) } $self->configure;
}

my $prefix;

sub _prefix {
    my $self = shift;
    return $prefix if defined $prefix;
    ( $prefix = ( ref($self) || $self ) ) =~ s/^Pod::Weaver::PluginBundle:://;
    $prefix;
}

sub _expand_config {
    my ( $self, $this_spec ) = @_;

    die 'undefined config' if not $this_spec;
    die 'unrecognized config format: ' . ref($this_spec)
        if ref($this_spec)
        and ref($this_spec) ne 'ARRAY';

    my ( $name, $class, $payload );

    if ( not ref $this_spec ) {
        ( $name, $class, $payload ) = ( $this_spec, _exp($this_spec), {} );
    }
    elsif ( @$this_spec == 1 ) {
        ( $name, $class, $payload )
            = ( $this_spec->[0], _exp( $this_spec->[0] ), {} );
    }
    elsif ( @$this_spec == 2 ) {
        $name = ref $this_spec->[1] ? $this_spec->[0] : $this_spec->[1];
        $class
            = _exp( ref $this_spec->[1] ? $this_spec->[0] : $this_spec->[0] );
        $payload = ref $this_spec->[1] ? $this_spec->[1] : {};
    }
    else {
        ( $name, $class, $payload )
            = ( $this_spec->[1], _exp( $this_spec->[0] ), $this_spec->[2] );
    }

    $name =~ s/^[@=-]//;

    # Region plugins have the custom plugin name moved to 'region_name' parameter,
    # because we don't want our bundle name to be part of the region name.
    if ( $class eq _exp('Region') ) {
        $name = $this_spec->[1];
        $payload = { region_name => $this_spec->[1], %$payload };
    }

    use_module( $class, $payload->{':version'} ) if $payload->{':version'};

    # prepend '@Author::DROLSKY/' to each class name,
    # except for Generic and Collect which are left alone.
    $name = '@' . $self->_prefix . '/' . $name
        if $class ne _exp('Generic')
        and $class ne _exp('Collect');

    return [ $name => $class => $payload ];
}

1;

# ABSTRACT: A plugin bundle for pod woven by DROLSKY

__END__

=pod

=head1 SYNOPSIS

In your F<weaver.ini>:

    [@Author::DROLSKY]

Or in your F<dist.ini>

    [PodWeaver]
    config_plugin = @Author::DROLSKY

It is also used automatically when your F<dist.ini> contains:

    [@Author::DROLSKY]
    :version = 0.094

=head1 DESCRIPTION

The contents of this bundle were mostly copied from
L<Pod::Weaver::PluginBundle::Author::ETHER>.

This is a L<Pod::Weaver> plugin bundle. It is I<approximately> equal to the
following F<weaver.ini>, minus some optimizations:

    [@CorePrep]

    [-SingleEncoding]

    [-Transformer / List]
    transformer = List

    [-Transformer / Verbatim]
    transformer = Verbatim

    [Region / header]
    [Name]
    [Version]

    [Region / prelude]

    [Generic / SYNOPSIS]
    [Generic / DESCRIPTION]
    [Generic / OVERVIEW]

    [Collect / ATTRIBUTES]
    command = attr

    [Collect / METHODS]
    command = method

    [Collect / FUNCTIONS]
    command = func

    [Collect / TYPES]
    command = type

    [Leftovers]

    [Region / postlude]

    [GenerateSection / generate SUPPORT]
    title = SUPPORT
    main_module_only = 0
    text = <template>

    [AllowOverride / allow override SUPPORT]
    header_re = ^(SUPPORT|BUGS)
    action = prepend
    match_anywhere = 0

    [GenerateSection / generate DONATIONS]
    title = DONATIONS
    main_module_only = 1
    text = ...

    [Authors]
    [Contributors]
    :version = 0.008

    [Legal]
    :version = 4.011
    header = COPYRIGHT AND <licence filename>

    [Region / footer]

This is also equivalent (other than section ordering) to:

    [-Transformer / List]
    transformer = List
    [-Transformer / Verbatim]
    transformer = Verbatim

    [Region / header]
    [@Default]

    [Collect / TYPES]
    command = type

    [GenerateSection / generate SUPPORT]
    title = SUPPORT
    main_module_only = 0
    text = <template>

    [AllowOverride / allow override SUPPORT]
    header_re = ^(SUPPORT|BUGS)
    action = prepend
    match_anywhere = 0

    [GenerateSection / generate DONATIONS]
    title = DONATIONS
    main_module_only = 0
    text = ...

    [Contributors]
    :version = 0.008

    [Region / footer]

=head1 OPTIONS

None at this time. (The bundle is never instantiated, so this doesn't seem to
be possible without updates to L<Pod::Weaver>.)

=head1 OVERRIDING A SPECIFIC SECTION

This F<weaver.ini> will let you use a custom C<COPYRIGHT AND LICENCE> section
and still use the plugin bundle:

    [@Author::DROLSKY]
    [AllowOverride / OverrideLegal]
    header_re = ^COPYRIGHT
    match_anywhere = 1

=head1 ADDING STOPWORDS FOR SPELLING TESTS

As noted in L<Dist::Zilla::PluginBundle::Author::DROLSKY>, stopwords for
spelling tests can be added by adding a directive to pod:

    =for stopwords foo bar baz

However, if the stopword appears in the module's abstract, it is moved to the
C<NAME> section, which will be above your stopword directive. You can handle
this by declaring the stopword in the special C<header> section, which will be
woven ahead of everything else:

    =for :header
    =for stopwords foo bar baz

=head1 SEE ALSO

=for :list
* L<Pod::Weaver>
* L<Pod::Weaver::PluginBundle::Default>
* L<Dist::Zilla::Plugin::PodWeaver>
* L<Dist::Zilla::PluginBundle::Author::DROLSKY>

=cut