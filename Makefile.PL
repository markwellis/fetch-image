use inc::Module::Install;

all_from('lib/Fetch/Image.pm');

requires 'LWPx::ParanoidAgent';
requires 'Data::Validate::Image';
requires 'Data::Validate::URI';
requires 'File::Temp';
requires 'Exception::Simple';
requires 'URI';

test_requires 'Test::More';
test_requires 'Test::Exception';

auto_install;
WriteAll;
