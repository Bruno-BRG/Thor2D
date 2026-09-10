# thor2d.Sound

LOVE equivalent: `love.sound`. Sources: `audio.odin`.

## Description

`Sound_Data` PCM: `New/Load/Clone/Convert`, sine fill, sample access; `Audio_Decoder` chunked decode.

## Format getters (v0.10 wave 4)

LOVE equivalent: `SoundData:getSampleRate/getChannelCount/getBitDepth`,
`Decoder:getSampleRate/getChannelCount/getBitDepth`. Source: `audio.odin`.

`Sound_Data` carries its format in the struct, so `Sound_Data_Sample_Rate`,
`Sound_Data_Channels` and `Sound_Data_Bit_Depth` are pure, nil-safe getters
(0 on nil). `Audio_Decoder_Channels`, `Audio_Decoder_Sample_Rate` and
`Audio_Decoder_Bit_Depth` read the format retained in the backend decoder
entry (decoders always produce f32 PCM, so a live decoder reports 32-bit);
bad handles or no device give 0, never a guess. Duration/seek/tell already
exist via `Sound_Data_Duration`, `Seek/Tell_Audio_Decoder` and
`Audio_Decoder_Length`.

## Functions

See [Api_Reference](../Api_Reference.md) for the full procedure index, and [Porting_From_LOVE](../guides/Porting_From_LOVE.md) for the LOVE mapping table.

## See Also

[Audio](Audio.md)
