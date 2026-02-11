//Change the instance name and port connections to the signal names
//--------Copy here to design--------

    LVDS_RX_rPLL2 your_instance_name(
        .clkout(clkout), //output clkout
        .lock(lock), //output lock
        .clkoutp(clkoutp), //output clkoutp
        .reset(reset), //input reset
        .clkin(clkin), //input clkin
        .psda(psda), //input [3:0] psda
        .dutyda(dutyda), //input [3:0] dutyda
        .fdly(fdly) //input [3:0] fdly
    );

//--------Copy end-------------------
