`timescale 1ns/1ps

// Модуль верхнего уровня: тактовый генератор, сброс,
// APB master + APB slave и тестовая последовательность.
module tb_top;

    parameter logic [31:0] P_DEVICE_OFFSET = 32'h7000_0000;

    // Данные студента (п.9)
    localparam logic [31:0] LIST_NUMBER = 32'd17;          // TODO: номер в списке группы
    localparam logic [31:0] DATE_BCD    = 32'h2910_2026;  // 29.10.2026 -> дд.мм.гггг в BCD
    localparam logic [31:0] SURNAME     = "Cher";         // первые 4 буквы фамилии (Chernykh)
    localparam logic [31:0] NAME        = "Alex";         // первые 4 буквы имени

    localparam logic [31:0] VAL_BIT0_IS_0 = 32'hAAAA_AAAA;
    localparam logic [31:0] VAL_BIT0_IS_1 = 32'h5555_5555;

    logic        pclk;
    logic        presetn;
    logic        psel;
    logic        penable;
    logic        pwrite;
    logic [31:0] paddr;
    logic [31:0] pwdata;
    logic [31:0] prdata;
    logic        pready;
    logic        pslverr;

    logic [31:0] data_from_device;
    int          errors = 0;

    apb_master master
    (
        .pclk(pclk), .presetn(presetn),
        .psel(psel), .penable(penable), .pwrite(pwrite),
        .paddr(paddr), .pwdata(pwdata),
        .prdata(prdata), .pready(pready), .pslverr(pslverr)
    );

    apb_slave DUT
    (
        .pclk(pclk), .presetn(presetn),
        .psel(psel), .penable(penable), .pwrite(pwrite),
        .paddr(paddr), .pwdata(pwdata),
        .prdata(prdata), .pready(pready), .pslverr(pslverr)
    );

    // Тактовый сигнал: период 20 нс (50 МГц)
    initial pclk = 1'b0;
    always #10ns pclk = ~pclk;

    task automatic check(input string what, input logic [31:0] got, input logic [31:0] expected);
        if (got === expected)
            $display("    PASS  %s: 0x%h", what, got);
        else
        begin
            $display("    FAIL  %s: got 0x%h, expected 0x%h", what, got, expected);
            errors++;
        end
    endtask

    // Запись + чтение обратно + проверка
    task automatic write_and_check(input string what, input logic [31:0] offset,
                                   input logic [31:0] wdata, input logic [31:0] expected);
        master.apb_write(P_DEVICE_OFFSET + offset, wdata);
        master.apb_read (P_DEVICE_OFFSET + offset, data_from_device);
        check(what, data_from_device, expected);
    endtask

    initial
    begin
        $timeformat(-9, 0, " ns", 8);
        if ($test$plusargs("monitor"))
            $monitor("APB IF: PSEL=%b PENABLE=%b PWRITE=%b PREADY=%b PSLVERR=%b PADDR=0x%h PWDATA=0x%h PRDATA=0x%h",
                     psel, penable, pwrite, pready, pslverr, paddr, pwdata, prdata);

        // Сброс
        presetn = 1'b1;
        repeat (5) @(posedge pclk);
        presetn = 1'b0;
        repeat (5) @(posedge pclk);
        presetn = 1'b1;
        repeat (5) @(posedge pclk);

        $display("\n=== п.8: правило регистра 0x0 ===");
        write_and_check("0x0, bit0=0", 32'h0, 32'h1234_5678, VAL_BIT0_IS_0);
        write_and_check("0x0, bit0=1", 32'h0, 32'h0000_0001, VAL_BIT0_IS_1);

        $display("\n=== п.9: данные студента ===");
        write_and_check("0x0, номер в списке", 32'h0, LIST_NUMBER,
                        LIST_NUMBER[0] ? VAL_BIT0_IS_1 : VAL_BIT0_IS_0);
        write_and_check("0x4, дата",           32'h4, DATE_BCD, DATE_BCD);
        write_and_check("0x8, фамилия",        32'h8, SURNAME,  SURNAME);
        write_and_check("0xC, имя",            32'hC, NAME,     NAME);

        $display("\n=== Неверный адрес ===");
        master.apb_write(P_DEVICE_OFFSET + 32'h10, 32'hDEAD_BEEF);
        if (master.last_slverr)
            $display("    PASS  PSLVERR выставлен для смещения 0x10");
        else
        begin
            $display("    FAIL  PSLVERR не выставлен для смещения 0x10");
            errors++;
        end

        $display("\n=== Итог: %0d ошибок ===\n", errors);
        repeat (10) @(posedge pclk);
        $stop();
    end

endmodule
