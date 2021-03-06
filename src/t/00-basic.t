use strict;
use warnings;
use 5.011;

use Test::More;
use Data::Dumper;

BEGIN { 
    use_ok('CIF');
    use_ok('CIF::Smrt');
    use_ok('CIF::Router');
};

use CIF qw/is_ip is_url is_ip_private is_fqdn/;

ok(is_ip('192.168.1.1'),'testing ip address...');
ok(is_url('http://12.12.12.12/example/test.html'), 'testing url...');

ok(is_ip_private('192.168.1.1'),'testing private ip...');
ok(!is_ip_private('128.205.1.1'),'testing public ip...');

ok(is_ip('2001:1608:10:147::21') eq 'ipv6', 'testing ipv6');
ok(is_ip('2001:da8:8001:2303:b58f:25b4:a6fc:509d') eq 'ipv6', 'testing ipv6');
ok(is_ip('2001:4860:4860::8888') eq 'ipv6', 'testing ipv6');
ok(is_ip('2001:4860:4860::8844') eq 'ipv6', 'testing ipv6');

ok(!is_ip('192.168.1.1.example.com'));
ok(is_fqdn('192.168.1.1.example.com'));
ok(is_url('192.168.1.1/html/1.thm'));
ok(!is_url('192.168.0.0/24'));
ok(is_fqdn('xn----jtbbmekqknepg3a.xn--p1ai'));
ok(!is_url('www'));
ok(is_url('http://fb.co'));
ok(!is_url('http://ww'));
ok(is_url('http://fb.com/1234.html'));
ok(is_url('http://192.168.1.1/1.html'));
ok(is_url('http://example.org/?q=12&1=2'));

ok(is_fqdn('update-your-account-information--cgi-bin-webscrcmd-login5w80ah.newageastrology.gr'), 'checking domain');
ok(is_fqdn('paypal_update_acouunt.joannebradybeauty.co.uk'), 'checking domain');
ok(is_fqdn('yahoo.uk'), 'checking domain');


ok(is_ip('2001:4860:4860::8888'));

done_testing();
