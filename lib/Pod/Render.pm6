#! /usr/bin/env perl6
use v6.c;
use Template::Mustache;
use JSON::Fast;
use nqp;

unit class Pod::Render;

=begin pod
=TITLE Rendering pod

This module provide functionality to take precompiled pod and generate
output based on templates. The default templates are for html and for a separate
HTML file for each source pod.

=begin SYNOPSIS

    use Pod::Render;

    my Pod::Render $renderer .= new(
        :path<path-to-pod-cache>,
        :templates<path-to-templates>,
        :output<path-to-output>,
        :rendering<html>,
        :!verbose );

=end SYNOPSIS
=item new
    - instantiates object and verifies cache is present
    - creates or empties the output directory
    - verifies that <templates>/<rendering> directory exists and contains
        a full set of templates

=item path
    - location of perl6 compunit cache, as generated by Pod::Cached
    - defaults to 'pod-cache'

=item templates
    - location of templates root directory
    - defaults to 'resources/templates', which is where a complete set of templates exists

=item output
    - the path where output is sent
    - default is a directory with the same name as C<rendering>

=item rendering
    - the type of rendering chosen
    - default is html, and refers to templates/html in which a complete set of templates exists
    - any other valid directory name can be used, eg md, so long as templates/md contains
    a complete set of templates

=end pod

has Str $!path;
has Str $!templates;
has Str $!rendering;
has @!template-list = <main>; # list of all the templates needed
has $!output;
has Bool $!verbose;
has %!files;
has $!precomp;
has $!precomp-store;

submethod BUILD(
    :$!templates = 'resources/templates',
    :$!rendering = 'html',
    :$!output = $!rendering,
    :$!verbose = True,
    :$!path = 'pod-cache',
    ) {
    die '$!path is not a directory' unless $!path.IO ~~ :d;
    die 'No file index in pod cache' unless "$!path/file-index.json".IO ~~ :f;
    %!files = from-json("$!path/file-index.json".IO.slurp);
    die 'No files in cache' unless +%!files.keys;
    $!precomp-store = CompUnit::PrecompilationStore::File.new(prefix => $!path.IO );
    $!precomp = CompUnit::PrecompilationRepository::Default.new(store => $!precomp-store);
    for %!files.kv -> $pod-name, %info {
        my $handle = $!precomp.load(%info<cache-key>)[0];
        with $handle {
            %!files{$pod-name}<handle> = $handle ;
        }
        else {
            die "pod cache is corrupt, missing data for $pod-name";
        }
    }
    note 'Cache verified' if $!verbose;
    self.verify-templates;
}

method verify-templates {
    return if $!templates eq 'resources/templates' and $!rendering eq 'html';
    die "$!templates/$!rendering must be a directory" unless "$!templates/$!rendering".IO ~~ :d;
    for @!template-list {
        die "$_.mustache must exist under $!templates/$!rendering"
            unless "$!templates/$!rendering/$_.mustache".IO ~~ :f
    }
    note 'Templates verified' if $!verbose;
}

method pod($filename) {
    nqp::atkey(%!files{$filename}<handle>.unit,'$=pod')[0];
}