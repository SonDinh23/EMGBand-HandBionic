#ifndef BUZZER_MUSIC_H
#define BUZZER_MUSIC_H

#include <Arduino.h>

#define PIN_BUZZER          19
#define BUZZER_CHANNEL      0
#define BUZZER_FREQUENCY    8000      // 8kHz
#define BUZZER_RESOLUTION   8        // 8-bit (duty từ 0–255)

enum stateBuzzer {
    play_beep = 0,
    play_beep_double = 1,
    play_warning = 2,
    play_startup = 3,
    play_melody = 4,
    play_beep_long = 5,
    play_beep_short = 6,
    play_error = 7,
    play_success = 8,
    play_vibration_alert = 9,
    play_shutdown = 10,
};

class BuzzerMusic {
    public:
        BuzzerMusic(/* args */);
        ~BuzzerMusic();

        void begin(void);
        void offBuzzer(void);
        void playSound(enum stateBuzzer state);
    private:
        void playTone(int freq, int duration);

        void play_beep();               // Beep ngắn	Xác nhận nhấn nút, OK
        void play_beep_double();        // Beep đôi	    Thông báo đơn giản
        void play_warning();            // Cảnh báo	    Cảnh báo lỗi, khẩn cấp
        void play_startup();            // Khởi động	Âm mở máy, hệ thống on
        void play_melody();             // Melody vui	Gợi ý hành động, hoàn tất
        void play_beep_long();          // Beep dài	    Âm đơn dài	Xác nhận dài, giữ nút
        void play_beep_short();         // Beep rút     gọn	Âm ngắn cực nhanh	Nhấn nhẹ, thao tác nhỏ
        void play_error();              // Sai	        Hai âm trầm	Báo lỗi, thao tác sai
        void play_success();            // Thành công	Ba âm tăng tông	Hoàn thành tác vụ
        void play_vibration_alert();	// Rung cảnh báo	5 âm nhanh xen kẽ	Báo nguy hiểm, lỗi liên tục
        void play_shutdown();           // Tắt máy	3 âm giảm dần tông	Thiết bị tắt
};


#endif