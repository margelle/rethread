//////////////////////////////////////////////////////
/////// SYNTHDEFS
/////////////////////////////////////////////////////

SynthDef(\bubbly_filter, { |out|
	var sig, maxfreq = \maxfreq.kr(2000), minfreq = \minfreq.kr(100), speed = \speed.kr(3), freq, in, delay_pan;
	speed = LFNoise1.kr(2).range(5, 12);
	freq = SinOsc.ar(speed).range(minfreq, maxfreq);
	in = In.ar(\in.kr(10), 2);
	// sig = RLPF.ar(in, freq, 0.1);
	sig = BMoog.ar(in, freq, 0.1, 0.0, 0.95);
	sig = sig + (LocalIn.ar(2).mirror * 0.7);
	delay_pan = LFNoise1.ar(LFNoise1.kr(0.1).range(0.1, 0.5)).range(-0.001, 0.001);
	sig = [DelayL.ar(sig[0], 0.1, delay_pan.max(0)), DelayL.ar(sig[1], 0.1, (delay_pan * -1).max(0))];
	LocalOut.ar(sig);
	Out.ar(out, sig * \amp.kr(0.5));
}).add;

SynthDef(\long_sine, {
	var sig, env, freq = \freq.kr(220);

	env = Env.sine(\length.kr(5)).kr(2);
	sig = SinOsc.ar(freq) * \amp.kr(0.2) * env * 0.1;
	sig = Pan2.ar(sig, \pan.kr(0));

	Out.ar(\out.kr(0), sig);
}).add;
SynthDef(\tick2, {
	var sig, env, rq = \rq.kr(0.1);
	env = Env.perc(\atk.kr(0), \rel.kr(0.05), curve: [\c0.kr(-4), \c1.kr(-4)]).ar(2);
	sig = Impulse.ar(0);
	sig = sig * 0.5;
	// high freq and rq values causes the filter to blow up violently
	sig = RHPF.ar(sig, \freq.kr(1000).min(18000).max(20), rq.min(5)) * env;
	sig = Pan2.ar(sig, \pan.kr(0)) * \amp.kr(1.0) * 10;
	sig = sig.tanh; // Should never happen, but better to soft clip
	Out.ar(\out.kr(0), sig);
}).add;
SynthDef(\gust, {
	var sig, env, rq = \rq.kr(0.1), atk = \atk.kr(0.5), rel = \rel.kr(1.5), freq = \freq.kr(1400).min(18000).max(100);
	env = Env.perc(atk, rel, curve: [\c0.kr(4), \c1.kr(-4)]).ar(2);
	sig = WhiteNoise.ar(0.005);
	// high freq and rq values causes the filter to blow up violently
	sig = RHPF.ar(sig, freq, rq.min(5)) * env * 10 * \amp.kr(1.0);
	sig = LPF.ar(sig, Rand(freq * 0.5, 20000));
	sig = Pan2.ar(sig, Line.kr(\pan1.kr(0), \pan2.kr(0), atk + rel));
	sig = sig.tanh; // Should never happen, but better to soft clip

	Out.ar(\out.kr(0), sig);
}).add;

// SynthDefs written by Eli Fieldsteel, https://sccode.org/1-5bA
//fm synth
SynthDef(\fm, {
	arg freq=500, mRatio=1, cRatio=1,
	index=1, iScale=5, cAtk=4, cRel=(-4),
	amp=0.2, atk=0.01, rel=3, pan=0,
	out=0, fx=0, fxsend=(-25);
	var car, mod, env, iEnv;

	//index of modulation
	iEnv = EnvGen.kr(
		Env(
			[index, index*iScale, index],
			[atk, rel],
			[cAtk, cRel]
		)
	);

	//amplitude envelope
	env = EnvGen.kr(Env.perc(atk,rel,curve:[cAtk,cRel]),doneAction:2);

	//modulator/carrier
	mod = SinOsc.ar(freq * mRatio, mul:freq * mRatio * iEnv);
	car = SinOsc.ar(freq * cRatio + mod) * env * amp;

	car = Pan2.ar(car, pan);

	//direct out/reverb send
	Out.ar(out, car);
	Out.ar(fx, car * fxsend.dbamp);
}).add;

SynthDef(\fm_reverse, {
	arg freq=500, mRatio=1, cRatio=1,
	index=1, iScale=5, cAtk=4, cRel=(-4),
	amp=0.2, atk=0.01, rel=3, pan=0,
	out=0, fx=0, fxsend=(-25);
	var car, mod, env, iEnv;

	//index of modulation
	iEnv = EnvGen.kr(
		Env(
			[index, index*iScale, index],
			[atk, rel],
			[cAtk, cRel]
		)
	);

	//amplitude envelope
	env = EnvGen.ar(Env(levels: [0, 1, 0.2, 1, 0], times: [0.001, 0.01, atk, rel], curve: [-4, 4, cAtk, cRel])
		,doneAction:2);

	//modulator/carrier
	mod = SinOsc.ar(freq * mRatio, mul:freq * mRatio * iEnv);
	car = SinOsc.ar(freq * cRatio + mod) * env * amp;

	car = Pan2.ar(car, pan);

	//direct out/reverb send
	Out.ar(out, car);
	Out.ar(fx, car * fxsend.dbamp);
}).add;

SynthDef(\kick, {arg out = 0, amp = 0.3, sinfreq = 60, glissf = 0.9, glisstime = 0.035, att = 0.01, rel = 0.45, pan = 0;
	var env, snd, ramp, click, clickAmp, clickAdd = \clickAdd.kr(100), sub, subAmp, wobble = \wobble.kr(0.1);
	env = Env.perc(att, rel, amp).ar(doneAction: 2);
	ramp = XLine.ar(
		start: sinfreq,
		end: sinfreq * glissf,
		dur: glisstime
	);
	snd = SinOsc.ar(freq: ramp, mul: env);
	clickAmp = EnvGen.ar(Env.perc(0.001, 0.01)) * 0.04;
	click = LPF.ar(Formant.ar(910 + clickAdd, 4760 + clickAdd, 2110 + clickAdd), Rand(3000, 4500)) * clickAmp;

	snd = snd + click;
	snd = Pan2.ar(snd, pan);
	subAmp = EnvGen.ar(Env.perc(att, rel)) * 0.15;
	sub = SinOsc.ar(sinfreq * glissf * {SinOsc.kr(8, phase: Rand(0, pi)).range(1.0-wobble, 1.0+wobble)}!2) * subAmp;
	snd = snd + sub;
	Out.ar(out, snd);
}).add;

SynthDef(\sub_tam, {
	// FM synth for a sub bass type sound rev_channel.buswith some noise on top
	var freq = \freq.kr(32), sig, env, sig1, sig2, sig3,
	mod1_1, mRatio = \mRatio.kr(2), mod1_2, mod2_1, mod2_2,
	mod2_1_ratio = 16*6, mod2_2_ratio = SinOsc.ar(freq*Rand(10, 14)).range(1, 16*8) *4,
	feedback, atk = \atk.kr(05), rel = \rel.kr(5), brightnessRamp, lowcut;

	env = Env.perc(atk, rel, 1.0, [\c0.kr(2), \c1.kr(-4)]).ar(2);

	brightnessRamp = XLine.kr(0.1, 1, atk);

	feedback = LocalIn.ar(1);
	mod1_2 = SinOsc.ar(freq * 8 + feedback, mul: freq * mRatio);
	LocalOut.ar(mod1_2 * 0.1);
	mod1_1 = SinOsc.ar(freq * mRatio + mod1_2, mul: freq * mRatio * Line.kr(0.0, 1.0, atk/2));
	sig1 = SinOsc.ar(freq + mod1_1) * env;

	mod2_2 = SinOsc.ar(freq * mod2_2_ratio, mul: freq * mod2_2_ratio * brightnessRamp * freq);
	mod2_1 = SinOsc.ar(freq * mod2_1_ratio + mod2_2, mul: freq * mod2_1_ratio * brightnessRamp);
	sig2 = SinOsc.ar(freq * 16 + mod2_1) * env.pow(1.5) * XLine.kr(0.05, 0.4, atk+rel);

	sig = sig1 + sig2;
	sig = sig * \amp.kr(0.5);
	// sig = sig + (DPW3Tri.ar(freq*2) * 0.5 * env.pow(3));
	lowcut = brightnessRamp.pow(3);
	sig = (HPF.ar(sig, 100) * lowcut) + (sig * (1-lowcut));

	sig = Pan2.ar(sig, \pan.kr(0));
	Out.ar(\out.kr(0), sig);
}).add;

SynthDef(\medium_reverb, { | out = 0, amp = 1, mix = 0.3  |
	var sig, wet;

	sig = In.ar(\in.kr(10), 2);
	mix = mix.lag(\mixLag.kr(10));

	wet = JPverb.ar(sig, 3.0, 0.9, 4.0, 0.8);
	wet = GVerb.ar(sig, 300, 103, 0.43, 0.51, 15, -5.dbamp, -26.dbamp, -20.dbamp);
	wet = Greyhole.ar(sig, \delayTime.kr(0.1), \damp.kr(0.7), \size.kr(1.0), \diff.kr(0.8), \feedback.kr(0.9));

	sig = (sig * (1-mix)) + (wet*mix);
	sig = Limiter.ar(sig, 0.95);
	Out.ar(out, sig);
}).add;

// Create different synthdefs for mixer_channels (incl. the encoder) and the decoder depending on the settings above.
if(~useAmbisonics, {
	SynthDef(\decoder, { | in = 10, out = 0 |
		var sig;
		sig = In.ar(in, ~mixerChannelOutputs.asInteger);
		if(~ambisonicsOrder == 1, {
			sig = KMHLSDome1h1pNormal6.ar(sig[0], sig[1], sig[2], sig[3], gain:-10);
		});
		if(~ambisonicsOrder == 3, {
			sig = KMHLSDome3h3pNormal6.ar(sig[0], sig[1], sig[2], sig[3], sig[4], sig[5], sig[6], sig[7],
				sig[8], sig[9], sig[10], sig[11], sig[12], sig[13], sig[14], sig[15], gain:-10);
		});
		if(~ambisonicsOrder == 5, {
			sig = KMHLSDome5h5pNormal6.ar(sig[0], sig[1], sig[2], sig[3], sig[4], sig[5], sig[6], sig[7],
				sig[8], sig[9], sig[10], sig[11], sig[12], sig[13], sig[14], sig[15],
				sig[16], sig[17], sig[18], sig[19], sig[20], sig[21], sig[22], sig[23],
				sig[24], sig[25], sig[26], sig[27], sig[28], sig[29], sig[30], sig[31],
				sig[32], sig[33], sig[34], sig[35], gain:-10);
		});
		Out.ar(out, sig);
	}).add;
	SynthDef(\mixer_channel, { | in = 10, out = 0 |
		var sig = In.ar(in, 2),
		// For the HOAEncoder* set of UGens, the azimuth is at the very left at pi/2 and the very right at -pi/2.
		// Going further moves us behind the origin.
		radius = \radius.kr(0.0), azimuth = \azimuth.kr(0.0), elevation = \elevation.kr(0), yes = \use_radius.kr(1.0);
		// radius = MouseY.kr(0.0, 1.0);
		if(~controlPositionWithMouse) {
			azimuth = azimuth + MouseX.kr(pi * 1, -pi * 1);
			elevation = elevation + MouseY.kr(pi * 0.5, 0);
		};
		sig = Mix(sig) * \amp.kr(0.5);
		if(~ambisonicsOrder == 1, {
			sig = HOAEncoder1.ar(
				sig,
				1.0,
				radius,
				azimuth,
				elevation,
				yes
			);
		});
		if(~ambisonicsOrder == 3, {
			sig = HOAEncoder3.ar(
				sig,
				1.0,
				radius,
				azimuth,
				elevation,
				yes
			);
		});
		if(~ambisonicsOrder == 5, {
			sig = HOAEncoder5.ar(
				sig,
				1.0,
				radius,
				azimuth,
				elevation,
				yes
			);
		});
		Out.ar(out, sig);
	}).add;
}, {
	// no ambisonics, just straight through as stereo
	SynthDef(\decoder, { |in = 10, out = 0 |
		var sig = In.ar(in, ~mixerChannelOutputs.asInteger);
		sig = Compander.ar(sig, sig, 0.5, 0.9, 1/2, 0.1, 0.3);
		sig = Limiter.ar(sig, 0.95);
		Out.ar(out, sig);
	}).add;

	SynthDef(\mixer_channel, { | in = 10, out = 0, send = 12, send_amp = 0, pan = 0, activity = 0 |
		var sig = In.ar(in, 2);
		sig = sig * \amp.kr(0.8);
		sig = Balance2.ar(sig[0], sig[1], pan);
		sig = Decimator.ar(sig, SampleRate.ir, activity.linlin(0, 1, 16, 8));
		Out.ar(out, sig);
		Out.ar(send, sig * send_amp);
	}).add;
});

SynthDef(\reverse_sine, {
	var sig, env, freq = \freq.kr(220);

	env = Env.perc(\atk.kr(2), \rel.kr(0.1), curve: [\c0.kr(\cub), \c1.kr(\sine)]).kr(2);
	sig = SinOsc.ar(freq) * env;
	2.do { |i| var mult = i+2;
		sig = sig + SinOsc.ar(freq * mult * 1.01, // * LFNoise1.kr(7).range(0.98, 1.02),
			mul: env.pow(mult*mult));
	};

	sig = sig * 0.3 * \amp.kr(0.5);
	sig = Pan2.ar(sig, \pan.kr(0));

	Out.ar(\out.kr(0), sig);
}).add;

SynthDef(\reverse_saw, {
	var sig, env, freq = \freq.kr(220), atk = \atk.kr(2), cutoffFreq;

	env = Env.perc(atk, \rel.kr(0.1), curve: [\c0.kr(\cub), \c1.kr(\sine)]).kr(2);
	sig = Saw.ar(freq) * env;
	2.do { |i| var mult = i+2;
		sig = sig + Saw.ar(freq * mult * 1.01, // * LFNoise1.kr(7).range(0.98, 1.02),
			mul: env.pow(mult*mult));
	};

	cutoffFreq = (freq*0.125 + (freq * env.pow(1.5) * 6)).min(18000);
	sig = LPF.ar(sig, cutoffFreq, atk);

	sig = sig * 0.3 * \amp.kr(0.5);
	sig = Pan2.ar(sig, \pan.kr(0));

	Out.ar(\out.kr(0), sig);
}).add;

SynthDef(\reverse_google, {
	var sig, env, freq = \freq.kr(220), atk = \atk.kr(2), rel = \rel.kr(0.1);

	env = Env.perc(atk, rel, curve: [\c0.kr(\cub), \c1.kr(\sine)]).kr(2);
	sig = Pulse.ar(freq) * env;
	2.do { |i| var mult = i+2;
		sig = sig + DPW3Tri.ar(freq * mult * 1.01, // * LFNoise1.kr(7).range(0.98, 1.02),
			mul: env.pow(mult*mult));
	};

	sig = sig * 0.3 * \amp.kr(0.5) * LFSaw.ar(Rand(1.5, 3)).range(0.2, 1.0).lag(0.01);
	sig = LPF.ar(sig, Line.kr(18000, freq, atk+rel));
	sig = Pan2.ar(sig, \pan.kr(0));

	Out.ar(\out.kr(0), sig);
}).add;


SynthDef(\thump, {
	var sig, env, freq = \freq.kr(220);
	env = Env.perc(\atk.kr(0.1), \rel.kr(2), curve: [\c0.kr(\cub), \c1.kr(\sine)]).kr(2);
	sig = Resonz.ar(PinkNoise.ar(mul: env.pow(100) * 20), freq, 0.007, mul: 20);
	sig = sig * \amp.kr(0.5);
	sig = Pan2.ar(sig, \pan.kr(0));
	Out.ar(\out.kr(0), sig);
}).add;

SynthDef(\softy, {
	var sig, env, freq = \freq.kr(220);
	env = Env.perc(\atk.kr(0.1), \rel.kr(2), curve: [\c0.kr(\cub), \c1.kr(\sine)]).kr(2);
	sig = Resonz.ar(PinkNoise.ar(mul: env), freq, 0.007, mul: 20);
	sig = sig * \amp.kr(0.5);
	sig = Pan2.ar(sig, \pan.kr(0));
	Out.ar(\out.kr(0), sig);
}).add;

SynthDef(\softy_sustained, {
	var sig, env, freq = \freq.kr(220), rq = 0.007, ampVariation, atk = \atk.kr(0.1), stutterTrig, stutterAmount = 1-\stutterAmount.kr(1),
	brightSig, brightness = \brightness.kr(0.0);
	brightness = brightness.pow(2);
	env = EnvGen.kr(Env.asr(atk, 1.0, \rel.kr(2), curve: [\c0.kr(\cub), \c1.kr(\sine)]),
		gate: \gate.kr(1), doneAction: 2);
	rq = LFNoise1.kr(Rand(0.4, 1.5)).range(\minrq.kr(0.005), \maxrq.kr(0.01));
	sig = Resonz.ar(PinkNoise.ar, freq, rq, mul: 20);
	brightSig = Mix(Pulse.ar(freq * [1, 1.002, 1.004, 1.006], 0.2)) * 0.25;
	sig = (sig * (1-brightness.pow(2))) + (brightSig * brightness);
	ampVariation = LFNoise1.kr(LFNoise1.kr(1.5).range(0.3, 2.0)).range(0.1, 1.0);
	sig = sig * env * \amp.kr(0.5, atk) * ampVariation;
	stutterTrig = Dust.kr(\stutterSpeed.kr(8));
	sig = sig * Demand.kr(stutterTrig, 0, Dseq([stutterAmount, 1], inf));
	sig = Pan2.ar(sig, \pan.kr(0, Rand(1.0, 3.0)));
	Out.ar(\out.kr(0), sig);
}).add;

SynthDef(\glitchy_rise, { | freq = 500, mRatio = 1, pan = 0, height = 2, atk = 0.1, rel = 1.1 |
	var sig, env, mod, modfreq;

	env = Env.perc(atk, rel, curve: [\c0.kr(2), \c1.kr(\sine)]).kr(2);

	modfreq = freq * Line.kr(1.0, height, atk + rel);
	mod = SinOsc.ar(modfreq * mRatio) * modfreq * mRatio;
	sig = Pulse.ar(min(max(modfreq + mod, 20), 20000)) * 0.07 * env;
	sig = sig + (Pulse.ar(freq) * 0.07 * env.pow(2));
	sig = Pan2.ar(sig, pan);
	Out.ar(\out.kr(0), sig);
}).add;

SynthDef(\bounce_away, { | freq = 300 |
	var trig, sig, pan = \pan.kr(0);
	trig = Impulse.ar(Line.ar(Rand(3, 10), Rand(5, 20), 2));
	sig = Saw.ar([freq, freq * 8, Rand(freq * 8, freq*12).min(19000), Rand(freq*13, freq*14).min(19000)]) * 0.3 * Decay.ar(trig, Line.kr(0.03, 0.005, 2));
	sig = Mix(sig);
	sig = sig * Env.perc(\atk.kr(0.01), \rel.kr(2), curve: [\c0.kr(2), \c1.kr(\sine)]).kr(2);
	sig = Pan2.ar(sig, pan) * \amp.kr(0.5);
	Out.ar(\out.kr(0), sig);
}).add;

SynthDef(\service_voice, {
	var buf = \buf.kr(0), sig, trig, pos, env, atk = ExpRand(0.1, BufDur.kr(buf)/2), rel = ExpRand(0.01, BufDur.kr(buf) - atk), rate;
	// sig = PlayBuf.ar(1, buf, BufRateScale.kr(buf) * Rand(0.8, 1.2), doneAction: 2);
	env = EnvGen.kr(Env(
		levels: [0, 1, 1, 0],
		times: [atk, BufDur.kr(buf) - atk - rel, rel]
	));
	trig = Dust.kr(Rand(15, 45));
	pos = Line.ar(0, 1, BufDur.kr(buf) * Rand(0.6, 1.2));
	rate = Rand(0.8, 1.2)
	sig = GrainBuf.ar(1, trig, Rand(0.07, 0.3), buf, rate, pos);
	sig = sig * 0.5 * \amp.kr(0.05) * env * 2;
	sig = [DelayL.ar(sig, 0.1, Rand(0.0001, 0.03)), DelayL.ar(sig, 0.1, Rand(0.0001, 0.03))];
	FreeSelf.kr(pos >= 1);

	// sig = Pan2.ar(sig, Rand(-0.7, 0.7));
	Out.ar(\out.kr(0), sig);
}).add;