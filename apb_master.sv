`timescale 1ns/1ps

// Простейший APB master для тестбенча.
// Транзакции выполняются задачами apb_write / apb_read,
// которые вызываются из модуля верхнего уровня (tb_top).
module apb_master
(
    input  logic        pclk,
    input  logic        presetn,
    output logic        psel,
    output logic        penable,
    output logic        pwrite,
    output logic [31:0] paddr,
    output logic [31:0] pwdata,
    input  logic [31:0] prdata,
    input  logic        pready,
    input  logic        pslverr
);

    logic last_slverr; // pslverr последней транзакции

    initial
    begin
        psel        = 1'b0;
        penable     = 1'b0;
        pwrite      = 1'b0;
        paddr       = '0;
        pwdata      = '0;
        last_slverr = 1'b0;
    end

    task automatic apb_write(input logic [31:0] addr, input logic [31:0] data);
        wait ((penable == 1'b0) && (pready == 1'b0));
        @(posedge pclk);                 // фаза SETUP
        psel   <= 1'b1;
        paddr  <= addr;
        pwdata <= data;
        pwrite <= 1'b1;
        @(posedge pclk);                 // фаза ACCESS
        penable <= 1'b1;
        @(posedge pclk);
        wait (pready == 1'b1);           // ждём готовности слейва
        @(posedge pclk);
        last_slverr = pslverr;
        psel    <= 1'b0;
        penable <= 1'b0;
        pwrite  <= 1'b0;
        @(posedge pclk);
        if (last_slverr)
            $display("[%0t] MASTER: write 0x%h <= 0x%h  (PSLVERR)", $time, addr, data);
        else
            $display("[%0t] MASTER: write 0x%h <= 0x%h", $time, addr, data);
    endtask

    task automatic apb_read(input logic [31:0] addr, output logic [31:0] data);
        wait ((penable == 1'b0) && (pready == 1'b0));
        @(posedge pclk);                 // фаза SETUP
        psel   <= 1'b1;
        pwrite <= 1'b0;
        paddr  <= addr;
        @(posedge pclk);                 // фаза ACCESS
        penable <= 1'b1;
        @(posedge pclk);
        wait (pready == 1'b1);
        @(posedge pclk);
        data        = prdata;            // захват данных до их сброса слейвом
        last_slverr = pslverr;
        psel    <= 1'b0;
        penable <= 1'b0;
        @(posedge pclk);
        if (last_slverr)
            $display("[%0t] MASTER: read  0x%h -> 0x%h  (PSLVERR)", $time, addr, data);
        else
            $display("[%0t] MASTER: read  0x%h -> 0x%h", $time, addr, data);
    endtask

endmodule
