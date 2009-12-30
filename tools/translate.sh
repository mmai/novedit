rm locale/novedit.pot
rgettext novedit.rb controlerNovedit.rb viewNovedit.rb modelNovedit.rb -o locale/novedit.pot
xgettext glade/noveditBase.glade glade/noveditDialogs.glade -o locale/noveditGlade.pot
cd locale

#Initial creation
#LANG=fr_FR.UTF-8 msginit -i novedit.pot -o fr/novedit.po
#LANG=fr_FR.UTF-8 msginit -i noveditGlade.pot -o fr/noveditGlade.po

#Updates
LANG=fr_FR.UTF-8 msgmerge fr/novedit.po novedit.pot --update
LANG=fr_FR.UTF-8 msgmerge fr/noveditGlade.po noveditGlade.pot --update 

echo "Pour traduire : cd fr; vim novedit.po; rmsgfmt novedit.po -o LC_MESSAGES/novedit.mo; rmsgfmt noveditGlade.po -o LC_MESSAGES/noveditGlade.mo"
