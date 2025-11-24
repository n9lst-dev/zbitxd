#include <stdio.h>
#include <string.h>
#include "ft8_lib/ft8/encode.h"
#include "ft8_lib/ft8/decode.h"
#include "ft8_lib/common/common.h"
#include "ft8_lib/common/wave.h"

// Minimal FT8 smoke test: encode a test message, then attempt a decode.
int main(void) {
    const char *msg = "CQ TEST FN20";
    ftx_message_t m = {0};
    if (!ftx_encode_text(msg, &m)) {
        fprintf(stderr, "encode failed\n");
        return 1;
    }
    float tones[FT8_SYMBOL_COUNT];
    if (!ftx_pack_message(&m, tones)) {
        fprintf(stderr, "pack failed\n");
        return 1;
    }
    // Synthesize a simple waveform for the tones (no noise, fixed pitch).
    float wf[FT8_MAX_FREQ * 2] = {0};
    const float base_freq = 1000.0f;
    const float dt = 1.0f / FT8_SAMPLE_RATE;
    int idx = 0;
    for (int sym = 0; sym < FT8_SYMBOL_COUNT; sym++) {
        float freq = base_freq + tones[sym] * FT8_TONE_SPACING;
        for (int k = 0; k < FT8_SYMBOL_LEN; k++) {
            wf[idx++] = sinf(2.0f * M_PI * freq * (k * dt));
        }
    }
    // Decode
    ftx_message_t out_msgs[10];
    int out_count = 0;
    if (!ftx_find_sync(wf, idx, out_msgs, 10, &out_count)) {
        fprintf(stderr, "decode failed\n");
        return 1;
    }
    printf("decoded %d messages\n", out_count);
    return out_count > 0 ? 0 : 1;
}
