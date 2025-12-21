#include <ruby.h>
#include <portaudio.h>
#include <string.h>
#include <stdlib.h>

// Ring buffer - lock-free single producer, single consumer
#define BUFFER_SIZE 32768  // ~750ms at 44.1kHz

static float ring_buffer[BUFFER_SIZE];
static volatile size_t write_pos = 0;
static volatile size_t read_pos = 0;

static PaStream *stream = NULL;
static int stream_active = 0;
static int sample_rate = 44100;

// Get available samples to read
static inline size_t buffer_available(void) {
    size_t w = write_pos;
    size_t r = read_pos;
    if (w >= r) return w - r;
    return BUFFER_SIZE - r + w;
}

// Get free space for writing
static inline size_t buffer_free(void) {
    return BUFFER_SIZE - buffer_available() - 1;
}

// PortAudio callback - runs in audio thread, NO GVL needed!
static int audio_callback(const void *input, void *output,
                          unsigned long frame_count,
                          const PaStreamCallbackTimeInfo *time_info,
                          PaStreamCallbackFlags status_flags,
                          void *user_data) {
    float *out = (float *)output;
    size_t available = buffer_available();

    for (unsigned long i = 0; i < frame_count; i++) {
        if (available > 0) {
            out[i] = ring_buffer[read_pos];
            read_pos = (read_pos + 1) % BUFFER_SIZE;
            available--;
        } else {
            out[i] = 0.0f;  // Underrun - output silence
        }
    }

    return paContinue;
}

// Ruby: NativeAudio.start(sample_rate)
static VALUE rb_start(VALUE self, VALUE rb_srate) {
    if (stream_active) {
        rb_raise(rb_eRuntimeError, "Stream already active");
    }

    sample_rate = NUM2INT(rb_srate);

    PaError err = Pa_Initialize();
    if (err != paNoError) {
        rb_raise(rb_eRuntimeError, "Pa_Initialize failed: %s", Pa_GetErrorText(err));
    }

    // Reset buffer
    write_pos = 0;
    read_pos = 0;
    memset(ring_buffer, 0, sizeof(ring_buffer));

    err = Pa_OpenDefaultStream(&stream,
                               0,              // no input
                               1,              // mono output
                               paFloat32,
                               sample_rate,
                               256,            // frames per buffer (low latency)
                               audio_callback,
                               NULL);

    if (err != paNoError) {
        Pa_Terminate();
        rb_raise(rb_eRuntimeError, "Pa_OpenDefaultStream failed: %s", Pa_GetErrorText(err));
    }

    err = Pa_StartStream(stream);
    if (err != paNoError) {
        Pa_CloseStream(stream);
        Pa_Terminate();
        rb_raise(rb_eRuntimeError, "Pa_StartStream failed: %s", Pa_GetErrorText(err));
    }

    stream_active = 1;
    return Qtrue;
}

// Ruby: NativeAudio.stop
static VALUE rb_stop(VALUE self) {
    if (!stream_active) return Qfalse;

    Pa_StopStream(stream);
    Pa_CloseStream(stream);
    Pa_Terminate();

    stream_active = 0;
    return Qtrue;
}

// Ruby: NativeAudio.push(array_of_floats)
static VALUE rb_push(VALUE self, VALUE samples) {
    if (!stream_active) {
        rb_raise(rb_eRuntimeError, "Stream not active");
    }

    Check_Type(samples, T_ARRAY);
    long len = RARRAY_LEN(samples);
    size_t free_space = buffer_free();

    // Only write what fits
    long to_write = (len < (long)free_space) ? len : (long)free_space;

    for (long i = 0; i < to_write; i++) {
        VALUE sample = rb_ary_entry(samples, i);
        ring_buffer[write_pos] = (float)NUM2DBL(sample);
        write_pos = (write_pos + 1) % BUFFER_SIZE;
    }

    return LONG2NUM(to_write);
}

// Ruby: NativeAudio.available -> how many samples can be written
static VALUE rb_available(VALUE self) {
    return SIZET2NUM(buffer_free());
}

// Ruby: NativeAudio.buffered -> how many samples are buffered
static VALUE rb_buffered(VALUE self) {
    return SIZET2NUM(buffer_available());
}

// Ruby: NativeAudio.active?
static VALUE rb_active_p(VALUE self) {
    return stream_active ? Qtrue : Qfalse;
}

void Init_radspberry_audio(void) {
    VALUE mNativeAudio = rb_define_module("NativeAudio");

    rb_define_singleton_method(mNativeAudio, "start", rb_start, 1);
    rb_define_singleton_method(mNativeAudio, "stop", rb_stop, 0);
    rb_define_singleton_method(mNativeAudio, "push", rb_push, 1);
    rb_define_singleton_method(mNativeAudio, "available", rb_available, 0);
    rb_define_singleton_method(mNativeAudio, "buffered", rb_buffered, 0);
    rb_define_singleton_method(mNativeAudio, "active?", rb_active_p, 0);
}
