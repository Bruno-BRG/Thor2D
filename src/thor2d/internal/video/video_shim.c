#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavutil/imgutils.h>
#include <libavutil/opt.h>
#include <libswscale/swscale.h>

#include <stdint.h>
#include <stdlib.h>
#include <string.h>

typedef struct Thor_Video {
    AVFormatContext *format;
    AVCodecContext *codec;
    AVStream *stream;
    AVPacket *packet;
    AVFrame *frame;
    struct SwsContext *scale;
    uint8_t *rgba;
    int rgba_size;
    int width;
    int height;
    double frame_rate;
    double duration;
    double position;
    double clock;
    int playing;
    int looping;
} Thor_Video;

static void thor_video_clear_frame(Thor_Video *video) {
    if (video != NULL && video->frame != NULL) {
        av_frame_unref(video->frame);
    }
}

static int thor_video_convert_frame(Thor_Video *video) {
    int size;
    uint8_t *destination[4] = {0};
    int destination_stride[4] = {0};

    if (video == NULL || video->frame == NULL || video->frame->width <= 0 || video->frame->height <= 0) {
        return 0;
    }

    video->scale = sws_getCachedContext(
        video->scale,
        video->frame->width,
        video->frame->height,
        (enum AVPixelFormat)video->frame->format,
        video->frame->width,
        video->frame->height,
        AV_PIX_FMT_RGBA,
        SWS_BILINEAR,
        NULL,
        NULL,
        NULL
    );
    if (video->scale == NULL) {
        return 0;
    }

    size = av_image_get_buffer_size(AV_PIX_FMT_RGBA, video->frame->width, video->frame->height, 1);
    if (size <= 0) {
        return 0;
    }
    if (size != video->rgba_size) {
        uint8_t *new_buffer = (uint8_t *)realloc(video->rgba, (size_t)size);
        if (new_buffer == NULL) {
            return 0;
        }
        video->rgba = new_buffer;
        video->rgba_size = size;
    }

    destination[0] = video->rgba;
    destination_stride[0] = video->frame->width * 4;
    sws_scale(
        video->scale,
        (const uint8_t *const *)video->frame->data,
        video->frame->linesize,
        0,
        video->frame->height,
        destination,
        destination_stride
    );
    video->width = video->frame->width;
    video->height = video->frame->height;
    return 1;
}

static int thor_video_decode_next(Thor_Video *video) {
    int result;

    if (video == NULL) {
        return 0;
    }

    for (;;) {
        result = av_read_frame(video->format, video->packet);
        if (result < 0) {
            if (video->looping) {
                if (av_seek_frame(video->format, video->stream->index, 0, AVSEEK_FLAG_BACKWARD) < 0) {
                    return 0;
                }
                avcodec_flush_buffers(video->codec);
                video->position = 0.0;
                video->clock = 0.0;
                continue;
            }
            video->playing = 0;
            video->position = video->duration;
            return 0;
        }

        if (video->packet->stream_index != video->stream->index) {
            av_packet_unref(video->packet);
            continue;
        }

        result = avcodec_send_packet(video->codec, video->packet);
        av_packet_unref(video->packet);
        if (result < 0) {
            continue;
        }

        for (;;) {
            result = avcodec_receive_frame(video->codec, video->frame);
            if (result == AVERROR(EAGAIN) || result == AVERROR_EOF) {
                break;
            }
            if (result < 0) {
                break;
            }

            if (!thor_video_convert_frame(video)) {
                thor_video_clear_frame(video);
                return 0;
            }
            if (video->frame->best_effort_timestamp != AV_NOPTS_VALUE) {
                video->position = (double)video->frame->best_effort_timestamp * av_q2d(video->stream->time_base);
            }
            thor_video_clear_frame(video);
            return 1;
        }
    }
}

void *thor_video_open(const char *path) {
    Thor_Video *video;
    const AVCodec *decoder;
    int stream_index;
    int result;

    if (path == NULL || path[0] == '\0') {
        return NULL;
    }
    video = (Thor_Video *)calloc(1, sizeof(*video));
    if (video == NULL) {
        return NULL;
    }
    result = avformat_open_input(&video->format, path, NULL, NULL);
    if (result < 0) {
        free(video);
        return NULL;
    }
    result = avformat_find_stream_info(video->format, NULL);
    if (result < 0) {
        avformat_close_input(&video->format);
        free(video);
        return NULL;
    }
    stream_index = av_find_best_stream(video->format, AVMEDIA_TYPE_VIDEO, -1, -1, &decoder, 0);
    if (stream_index < 0 || decoder == NULL) {
        avformat_close_input(&video->format);
        free(video);
        return NULL;
    }
    video->stream = video->format->streams[stream_index];
    video->codec = avcodec_alloc_context3(decoder);
    video->packet = av_packet_alloc();
    video->frame = av_frame_alloc();
    if (video->codec == NULL || video->packet == NULL || video->frame == NULL) {
        avcodec_free_context(&video->codec);
        av_packet_free(&video->packet);
        av_frame_free(&video->frame);
        avformat_close_input(&video->format);
        free(video);
        return NULL;
    }
    result = avcodec_parameters_to_context(video->codec, video->stream->codecpar);
    if (result < 0 || avcodec_open2(video->codec, decoder, NULL) < 0) {
        avcodec_free_context(&video->codec);
        av_packet_free(&video->packet);
        av_frame_free(&video->frame);
        avformat_close_input(&video->format);
        free(video);
        return NULL;
    }

    video->width = video->codec->width;
    video->height = video->codec->height;
    video->frame_rate = av_q2d(av_guess_frame_rate(video->format, video->stream, NULL));
    if (video->frame_rate <= 0.0) {
        video->frame_rate = 0.0;
    }
    if (video->stream->duration != AV_NOPTS_VALUE) {
        video->duration = (double)video->stream->duration * av_q2d(video->stream->time_base);
    } else if (video->format->duration != AV_NOPTS_VALUE) {
        video->duration = (double)video->format->duration / (double)AV_TIME_BASE;
    }
    video->playing = 0;
    return video;
}

void thor_video_close(void *opaque) {
    Thor_Video *video = (Thor_Video *)opaque;
    if (video == NULL) {
        return;
    }
    sws_freeContext(video->scale);
    avcodec_free_context(&video->codec);
    av_packet_free(&video->packet);
    av_frame_free(&video->frame);
    avformat_close_input(&video->format);
    free(video->rgba);
    free(video);
}

void thor_video_play(void *opaque) {
    Thor_Video *video = (Thor_Video *)opaque;
    if (video != NULL) {
        video->playing = 1;
        if (video->rgba == NULL) {
            thor_video_decode_next(video);
        }
    }
}

void thor_video_pause(void *opaque) {
    Thor_Video *video = (Thor_Video *)opaque;
    if (video != NULL) {
        video->playing = 0;
    }
}

void thor_video_set_loop(void *opaque, int looping) {
    Thor_Video *video = (Thor_Video *)opaque;
    if (video != NULL) {
        video->looping = looping != 0;
    }
}

int thor_video_seek(void *opaque, double seconds) {
    Thor_Video *video = (Thor_Video *)opaque;
    int64_t timestamp;
    if (video == NULL) {
        return 0;
    }
    timestamp = (int64_t)(seconds / av_q2d(video->stream->time_base));
    if (av_seek_frame(video->format, video->stream->index, timestamp, AVSEEK_FLAG_BACKWARD) < 0) {
        return 0;
    }
    avcodec_flush_buffers(video->codec);
    video->position = seconds;
    video->clock = seconds;
    video->rgba_size = 0;
    free(video->rgba);
    video->rgba = NULL;
    return 1;
}

int thor_video_update(void *opaque, double delta) {
    Thor_Video *video = (Thor_Video *)opaque;
    if (video == NULL || !video->playing) {
        return 1;
    }
    if (delta > 0.0) {
        video->clock += delta;
    }
    if (video->rgba == NULL) {
        thor_video_decode_next(video);
    }
    while (video->playing && video->position + 0.000001 < video->clock) {
        if (!thor_video_decode_next(video)) {
            break;
        }
    }
    return 1;
}

int thor_video_frame(void *opaque, const unsigned char **pixels, int *width, int *height) {
    Thor_Video *video = (Thor_Video *)opaque;
    if (video == NULL || video->rgba == NULL || pixels == NULL || width == NULL || height == NULL) {
        return 0;
    }
    *pixels = video->rgba;
    *width = video->width;
    *height = video->height;
    return 1;
}

double thor_video_duration(void *opaque) {
    Thor_Video *video = (Thor_Video *)opaque;
    return video != NULL ? video->duration : 0.0;
}

double thor_video_position(void *opaque) {
    Thor_Video *video = (Thor_Video *)opaque;
    return video != NULL ? video->position : 0.0;
}

int thor_video_width(void *opaque) {
    Thor_Video *video = (Thor_Video *)opaque;
    return video != NULL ? video->width : 0;
}

int thor_video_height(void *opaque) {
    Thor_Video *video = (Thor_Video *)opaque;
    return video != NULL ? video->height : 0;
}

double thor_video_frame_rate(void *opaque) {
    Thor_Video *video = (Thor_Video *)opaque;
    return video != NULL ? video->frame_rate : 0.0;
}
