my %abo_map = (

    # Euripides
    'tlg,0006,001' => 'tlg,0006,034',
    'tlg,0006,002' => 'tlg,0006,035',
    'tlg,0006,003' => 'tlg,0006,036',
    'tlg,0006,004' => 'tlg,0006,037',
    'tlg,0006,005' => 'tlg,0006,038',
    'tlg,0006,006' => 'tlg,0006,039',
    'tlg,0006,007' => 'tlg,0006,040',
    'tlg,0006,008' => 'tlg,0006,041',
    'tlg,0006,012' => 'tlg,0006,042',
    'tlg,0006,009' => 'tlg,0006,043',
    'tlg,0006,011' => 'tlg,0006,044',
    'tlg,0006,013' => 'tlg,0006,045',
    'tlg,0006,010' => 'tlg,0006,046',
    'tlg,0006,014' => 'tlg,0006,047',
    'tlg,0006,015' => 'tlg,0006,048',
    'tlg,0006,016' => 'tlg,0006,049',
    'tlg,0006,017' => 'tlg,0006,050',
    'tlg,0006,018' => 'tlg,0006,051',
    'tlg,0006,019' => 'tlg,0006,052',

    # Arrian -> Epictetus
    'tlg,0074,-02' => 'tlg,0557,001',

    # Digest of Justinian
    'phi,2806,001' => 'phi,2806,002',
    );

my %suet_map = (
    '011' => 'Jul',
    '012' => 'Aug',
    '013' => 'Tib',
    '014' => 'Cal',
    '015' => 'Cl',
    '016' => 'Nero',
    '017' => 'Gal',
    '018' => 'Otho',
    '019' => 'Vit',
    '020' => 'Ves',
    '021' => 'Tit',
    '022' => 'Dom',
    );

my $unmodernise_urn = sub
{
    my $work = shift;
    $work =~ s/\.perseus-lat\d|\.perseus-grc\d//;
    $work =~ s/^(phi|tlg),?/$1,/;
    $work =~ s/\.(phi|tlg)/,/g;
    return $work;
};

$Diogenes::Perseus::translate_abo = sub {
    my $abo = shift;
    $abo = $unmodernise_urn->($abo);

    if ($abo =~ m/^([^:]+)(:.+)$/) {
        my ($work, $loc) = ($1, $2);

        if ($work =~ m/^phi,1348,(\d\d\d)$/) {
            my $num = $1;
            if ($num eq '001') {
                # In the Logeion L-S, the Lives of Suetonius as a
                # whole are work 001, and the name of the emperor is
                # added as "life=" in the citation part
                if ($loc =~ m/^:life=([^:]+)(:.*)/) {
                    my $life = $1;
                    my $chap = $2;
                    $life =~ s/(.*)\.$/\u$1/; # Title case and remove period
                    $abo = 'phi,1348,001:' . $life . $chap;
                }
            }
            elsif ($num) {
                # In the newer Perseus L-S, referencing of Suetonius
                # has changed so that the lives of the Caesars are now
                # independent, numbered works rather than named books
                # of a single work.
                $abo = 'phi,1348,001:' . $suet_map{$num} . $loc;
            }
            else {
                print STDERR "Could not understand Suetonius abo: $abo\n"
            }
        }
        elsif ($work =~ m/^phi,0060,(\d\d\d)$/) {
            # The 2019 version of the Perseus L-S lexicon erroneously gives Tibullus the number 0060 instead of 0660.
            $abo = 'phi,0660,' . $1 . $loc;
        }
        elsif ($work =~ m/^tlg,0059/) {
            # Plato needs the part of Stephanus page broken off
            if ($loc =~ m/^:(\d+)([a-z])$/) {
                $abo = $work.':'.$1.':'.$2;
            }
        }
        elsif ($work =~ m/^phi,0631,001$/) {
            # All of Sallust's works have by work number 001.  We only
            # deal with C. and J. here
            if ($loc =~ m/^:([CJ])\.\s*(.*)$/) {
                my ($CJ, $rest) = ($1, $2);
                $abo = 'phi,0631,00' . ($CJ eq 'C' ? '1' : '2');
                $abo .= ':'.$rest;
            }

        }
        elsif ($work =~ m/^phi,0474,(\d+)$/) {
            # For Cicero's speeches (n<36) we need to remove the first
            # term if there are two and the middle one if there are
            # three. When we get chapter=n, we just leave n, even
            # though these citations are generally wrong.  Likewise
            # with the Orator and such works.
            my $wk_num = $1;
            if ($wk_num == 5) {
                # For the Verrines, assume actio 2 (not always right)
                $loc =~ s/:\d+:section=(.*)$/:$1/;
                $loc = ':2'.$loc;
                $abo = $work.$loc;
            }
            # Letters are OK
            elsif ($wk_num < 56 or $wk_num > 59) {
                $loc =~ s/^://;
                my @locs = split m/:/, $loc;
                if (@locs == 3) {
                    $abo = $work.':'.$locs[0].':'.$locs[2];
                }
                elsif (@locs == 2) {
                    $abo = $work.':'.$locs[1];
                }
                elsif (@locs == 1) {
                    my $chap = $locs[0];
                    $chap =~ s/chapter=(.*)$/$1/;
                    $abo = $work.':'.$chap;
                }
            }
        }
        else {
            $abo = $work.$loc;
        }

        $abo = $abo_map{$work}.$loc if exists $abo_map{$work};
    }
    elsif ($abo =~ m/^([^:]+)$/) {
        $abo = $1 . ",0:0";
    }
    return $abo;
};
