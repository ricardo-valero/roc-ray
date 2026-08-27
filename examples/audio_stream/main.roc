## Exercises the PCM stream effects: a 440 Hz square wave is generated in Roc
## and pushed through Audio.Stream, regulated by buffered depth so the ring
## never underruns. You should hear a steady tone; Esc exits.
app [Model, program] { rr: platform "https://github.com/lukewilliamboswell/roc-ray/releases/download/0.10.0-rc3/3vVeddfDE6rraq5j8v1cGHtFNaQhC6dij1zGRN63NGP1.tar.zst", roc: "nightly-2026-08-23-fb208ba" }

import rr.App
import rr.Audio
import rr.Color
import rr.Draw
import rr.Text

sample_rate : U64
sample_rate = 48000

## Keep ~100 ms queued: comfortably above the device pull cadence, well under
## the host ring's ~250 ms capacity.
target_depth : U64
target_depth = 4800

chunk_frames : U64
chunk_frames = 1200

Model : {
	stream : Audio.Stream,
	status : Text.Prepared,
	t : U64, # stereo frames generated since startup
}

Msg : []

program = { init!, update!, render! }

init! : App.Init(Model, [ResourceLimit, StreamCreateFailed])
init! = App.init(
	App.default.with_title("RocRay audio stream").with_size({ width: 480, height: 200 }),
	|_startup| {
		font = Draw.default_font!()
		stream = Audio.create_stream!({ sample_rate: 48000, channels: 2 })?
		status = Text.from("440 Hz square wave via Audio.Stream — Esc exits", font).size(20).prepare!()?
		Ok({ stream, status, t: 0 })
	},
)

update! : Model, App.Input(Msg) => Try(Model, [Exit(I64), ..])
update! = |model, input| {
	if input.devices.key_pressed(KeyEscape) {
		Err(Exit(0))
	} else {
		# Top the ring back up to the target depth each update.
		var t = model.t
		while model.stream.buffered!() < target_depth {
			model.stream.push!(square_chunk(t))
			t = t + chunk_frames
		}
		Ok({ ..model, t })
	}
}

render! : Model, Draw.Frame => Try({}, [Exit(I64), ..])
render! = |model, frame| {
	frame.clear!(Color.from_hex_rgb(0x0d1425))
	model.status.draw!(frame, { pos: { x: 240, y: 88 }, color: Color.white, align: (Top, Center) })
	Ok({})
}

## One interleaved stereo chunk of a 440 Hz square wave starting at frame
## `start`: 880 half-periods per second, so a frame is in the high half when
## (t * 880) mod 96000 lands in the first 48000.
square_chunk : U64 -> List(F32)
square_chunk = |start| {
	var out = List.repeat(0.0, chunk_frames * 2)
	var i = 0
	while i < chunk_frames {
		t = start + i
		s = if (t * 880) % (sample_rate * 2) < sample_rate {
			0.15
		} else {
			-0.15
		}
		out = out.set(i * 2, s) ?? out
		out = out.set(i * 2 + 1, s) ?? out
		i = i + 1
	}
	out
}
