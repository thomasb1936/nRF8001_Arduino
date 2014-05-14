nrf8001 is an alternative radio stack for the TI nrf8001 radio, using the
rfxlink library (lib/rfxlink). The stack is IEEE802.15.4 compliant. It does
not support hardware acknowledgements or security. All the rfxlink features
are supported. See lib/rfxlink/README.txt for details.

To use this stack, simply wire against nrf8001ActiveMessageC instead of
ActiveMessageC.
