//Change the instance name and port connections to the signal names
//--------Copy here to design--------

    LVDS_TX_rPLL2 your_instance_name(
        .clkout(clkout), //output clkout
        .lock(lock), //output lock
        .reset(reset), //input reset
        .clkin(clkin) //input clkin
    );

//--------Copy end-------------------
