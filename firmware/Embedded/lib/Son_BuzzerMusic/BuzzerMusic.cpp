#include "BuzzerMusic.h"

BuzzerMusic::BuzzerMusic(/* args */) {}

BuzzerMusic::~BuzzerMusic() {}

void BuzzerMusic::begin(void) {
    ledcSetup(BUZZER_CHANNEL, BUZZER_FREQUENCY, BUZZER_RESOLUTION);
    ledcAttachPin(PIN_BUZZER, BUZZER_CHANNEL);
}

void BuzzerMusic::offBuzzer(void) {
    ledcDetachPin(PIN_BUZZER);
    digitalWrite(PIN_BUZZER, LOW);
}

void BuzzerMusic::playSound(enum stateBuzzer state) {
    switch(state) {
      case 0: play_beep(); break;
      case 1: play_beep_double(); break;
      case 2: play_warning(); break;
      case 3: play_startup(); break;
      case 4: play_melody(); break;
      case 5: play_beep_long(); break;
      case 6: play_beep_short(); break;
      case 7: play_error(); break;
      case 8: play_success(); break;
      case 9: play_vibration_alert(); break;
      case 10: play_shutdown(); break;
      default: break;
    }
}

// Hàm tạo âm
void BuzzerMusic::playTone(int freq, int duration)
{
    ledcWriteTone(0, freq);
    delay(duration);
    ledcWriteTone(0, 0); // Tắt âm
}

// 1. Beep ngắn – xác nhận
void BuzzerMusic::play_beep()
{
    playTone(2000, 100);
}

// 2. Beep đôi – thông báo
void BuzzerMusic::play_beep_double()
{
    playTone(1500, 100);
    delay(100);
    playTone(2000, 100);
}

// 3. Cảnh báo – lặp âm cao/thấp
void BuzzerMusic::play_warning()
{
    for (int i = 0; i < 3; i++)
    {
        playTone(1000, 200);
        delay(100);
        playTone(500, 200);
        delay(100);
    }
}

// 4. Âm khởi động – tăng dần cao độ
void BuzzerMusic::play_startup()
{
    int notes[] = {400, 600, 800, 1000, 1200};
    for (int i = 0; i < 5; i++)
    {
        playTone(notes[i], 120);
        delay(30);
    }
}

// 5. Giai điệu vui – DO RE MI
void BuzzerMusic::play_melody()
{
    int melody[] = {262, 294, 330}; // C D E
    for (int i = 0; i < 3; i++)
    {
        playTone(melody[i], 200);
        delay(50);
    }
}

// 6. Beep dài – xác nhận giữ
void BuzzerMusic::play_beep_long()
{
    playTone(2000, 500);
}

// 7. Beep rút gọn – phản hồi cực nhanh
void BuzzerMusic::play_beep_short()
{
    playTone(3000, 50);
}

// 8. Sai – âm đôi trầm
void BuzzerMusic::play_error()
{
    playTone(400, 200);
    delay(100);
    playTone(300, 200);
}

// 9. Thành công – 3 âm tăng dần
void BuzzerMusic::play_success()
{
    int notes[] = {1000, 1500, 2000};
    for (int i = 0; i < 3; i++)
    {
        playTone(notes[i], 150);
        delay(50);
    }
}

// 10. Rung cảnh báo – 5 âm nhanh
void BuzzerMusic::play_vibration_alert()
{
    for (int i = 0; i < 5; i++)
    {
        playTone((i % 2 == 0) ? 900 : 1100, 100);
        delay(30);
    }
}

// 11. Âm tắt máy – giảm dần
void BuzzerMusic::play_shutdown()
{
    int notes[] = {1000, 700, 400};
    for (int i = 0; i < 3; i++)
    {
        playTone(notes[i], 200);
        delay(30);
    }
}
