diff --git a/check_rbl/check_rbl-1.3.5/check_rbl.ini b/check_rbl/check_rbl-1.3.5/check_rbl.ini
index aeebf6d..451d499 100644
--- a/check_rbl/check_rbl-1.3.5/check_rbl.ini
+++ b/check_rbl/check_rbl-1.3.5/check_rbl.ini
@@ -14,7 +14,7 @@ server=relays.nether.net
 server=dnsbl.njabl.org
 server=bhnc.njabl.org
 server=no-more-funn.moensted.dk
-server=rbl.orbitrbl.com
+;server=rbl.orbitrbl.com ; domain offline
 server=psbl.surriel.com
 server=dyna.spamrats.com
 server=noptr.spamrats.com
