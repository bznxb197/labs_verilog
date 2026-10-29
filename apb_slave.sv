`timescale 1ns/1ps

// APB slave с регистром по смещению 0x0.
// Регистр 0x0 (register_with_some_name) работает по правилу ЛР:
//   запись с pwdata[0] = 0 -> в регистре хранится 32'hAAAA_AAAA,
//   запись с pwdata[0] = 1 -> в регистре хранится 32'h5555_5555.
// Обращение по другому смещению -> pslverr = 1.
// О каждой операции слейв печатает сообщение в консоль симулятора.
module apb_slave
(
    input  logic        pclk,     // синхросигнал
    input  logic        presetn,  // сигнал сброса (инверсный)
    input  logic [31:0] paddr,    // адрес обращения
    input  logic [31:0] pwdata,   // данные для записи
    input  logic        psel,     // признак выбора устройства
    input  logic        penable,  // признак активной транзакции
    input  logic        pwrite,   // признак операции записи
    output logic        pready,   // признак готовности от устройства
    output logic        pslverr,  // признак ошибки при обращении
    output logic [31:0] prdata    // прочитанные данные
);

    localparam logic [31:0] VAL_BIT0_IS_0 = 32'hAAAA_AAAA;
    localparam logic [31:0] VAL_BIT0_IS_1 = 32'h5555_5555;

    logic [31:0] register_with_some_name; // смещение 0x0

    // Состояния автомата APB
    typedef enum logic [1:0] {
        APB_SETUP,
        APB_W_ENABLE,
        APB_R_ENABLE
    } apb_state_t;

    apb_state_t apb_st;

    always @(posedge pclk)
        if (!presetn)
        begin
            prdata                  <= '0;
            pslverr                 <= 1'b0;
            pready                  <= 1'b0;
            register_with_some_name <= '0;
            apb_st                  <= APB_SETUP;
        end
        else
        begin
            case (apb_st)
                APB_SETUP:
                begin: apb_setup_st
                    // Очистка результатов предыдущей транзакции
                    prdata  <= '0;
                    pready  <= 1'b0;
                    pslverr <= 1'b0;

                    // Фаза SETUP: psel = 1, penable = 0
                    if (psel && !penable)
                    begin
                        if (pwrite)
                            apb_st <= APB_W_ENABLE;
                        else
                            apb_st <= APB_R_ENABLE;
                    end
                end: apb_setup_st

                APB_W_ENABLE:
                begin: apb_w_en_st
                    if (psel && penable && pwrite)
                    begin
                        pready <= 1'b1;
                        case (paddr[7:0])
                            8'h0: begin
                                register_with_some_name <= pwdata[0] ? VAL_BIT0_IS_1 : VAL_BIT0_IS_0;
                                $display("[%0t] SLAVE: WRITE 0x%h <= 0x%h (bit0=%b -> reg = 0x%h)",
                                         $time, paddr, pwdata, pwdata[0],
                                         pwdata[0] ? VAL_BIT0_IS_1 : VAL_BIT0_IS_0);
                            end
                            default: begin
                                pslverr <= 1'b1;
                                $display("[%0t] SLAVE: WRITE 0x%h <= 0x%h -> ERROR: no register at this offset",
                                         $time, paddr, pwdata);
                            end
                        endcase
                        apb_st <= APB_SETUP;
                    end
                end: apb_w_en_st

                APB_R_ENABLE:
                begin: apb_r_en_st
                    if (psel && penable && !pwrite)
                    begin
                        pready <= 1'b1;
                        case (paddr[7:0])
                            8'h0: begin
                                prdata <= register_with_some_name;
                                $display("[%0t] SLAVE: READ  0x%h -> 0x%h", $time, paddr, register_with_some_name);
                            end
                            default: begin
                                pslverr <= 1'b1;
                                $display("[%0t] SLAVE: READ  0x%h -> ERROR: no register at this offset",
                                         $time, paddr);
                            end
                        endcase
                        apb_st <= APB_SETUP;
                    end
                end: apb_r_en_st

                default:
                begin
                    pslverr <= 1'b1;
                    apb_st  <= APB_SETUP;
                end
            endcase
        end

endmodule
