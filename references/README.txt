================================================================================
  HAM RADIO OFFLINE REFERENCES
================================================================================
This folder is baked into the image so it works with NO Internet access.
Open it any time from the XFCE menu: Ham Radio > Ham Radio References
(or it's at /usr/share/ham-references, and linked at ~/References).

CONTENTS
--------
  FCC-Part-97.pdf
      The complete FCC amateur-radio rules (47 CFR Part 97), the official
      annual CFR edition from the U.S. Government Publishing Office
      (govinfo.gov). Public domain. View with the PDF viewer (zathura).

  US-Amateur-Band-Privileges.txt
      A quick-reference summary of U.S. amateur frequency privileges by
      license class, derived from the public-domain FCC allocations in
      Part 97. Plain text — open in any editor, or print it for the go-kit.

ABOUT THE "ARRL BAND PLAN"
--------------------------
The ARRL Band Plan (the familiar color band chart, and the voluntary
sub-band conventions for where SSB / CW / digital operate within each band)
is copyrighted by the ARRL, so it is NOT redistributed inside this image.
The *legal* allocation — what you're actually licensed to transmit — is the
FCC data included here. To add ARRL's chart for the operating conventions:
download it from http://www.arrl.org/band-plan (and the graphical chart from
http://www.arrl.org/graphical-frequency-allocations) while you have Internet,
and drop the PDF into this folder or into the container's installers/ share.

UPDATING
--------
Rules change. These files reflect the CFR edition current at build time
(see the build date of the image). Rebuild the container to refresh Part 97,
or replace FCC-Part-97.pdf with a newer edition from govinfo.gov.
================================================================================
