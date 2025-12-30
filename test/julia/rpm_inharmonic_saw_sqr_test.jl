using DSP, FFTW, Plots, Statistics
gr()

fs = 48000.0
f0 = 220.0
omega = 2π * f0 / fs
N = 65536
discard = 8192

# IIR Hilbert transformer using 6-stage second-order allpass filters
mutable struct HilbertIIR
    a_hi::Vector{Float64}
    a_lo::Vector{Float64}
    state_hi_i::Vector{Vector{Float64}}
    state_hi_o::Vector{Vector{Float64}}
    state_lo_i::Vector{Vector{Float64}}
    state_lo_o::Vector{Vector{Float64}}
    hi_delay::Float64
end

function HilbertIIR()
    c_hi = [0.5131884, 0.8133175, 0.9359722, 0.9791145, 0.9934793, 0.9989305]
    c_lo = [0.2755710, 0.6922636, 0.8896328, 0.9633075, 0.9882633, 0.9965990]
    HilbertIIR(c_hi .^ 2, c_lo .^ 2,
        [[0.0, 0.0] for _ in 1:6], [[0.0, 0.0] for _ in 1:6],
        [[0.0, 0.0] for _ in 1:6], [[0.0, 0.0] for _ in 1:6], 0.0)
end

function tick!(h::HilbertIIR, input::Float64)
    hi_in = input
    for m in 1:6
        hi_out = h.a_hi[m] * (hi_in + h.state_hi_o[m][2]) - h.state_hi_i[m][2]
        h.state_hi_i[m][2] = h.state_hi_i[m][1]; h.state_hi_i[m][1] = hi_in
        h.state_hi_o[m][2] = h.state_hi_o[m][1]; h.state_hi_o[m][1] = hi_out
        hi_in = hi_out
    end
    i_out = h.hi_delay; h.hi_delay = hi_in

    lo_in = input
    for m in 1:6
        lo_out = h.a_lo[m] * (lo_in + h.state_lo_o[m][2]) - h.state_lo_i[m][2]
        h.state_lo_i[m][2] = h.state_lo_i[m][1]; h.state_lo_i[m][1] = lo_in
        h.state_lo_o[m][2] = h.state_lo_o[m][1]; h.state_lo_o[m][1] = lo_out
        lo_in = lo_out
    end
    (i_out, lo_in)
end

mutable struct FreqShifterSSB
    hilbert::HilbertIIR; shift_hz::Float64; sample_rate::Float64; phase::Float64
end
FreqShifterSSB(shift_hz, fs) = FreqShifterSSB(HilbertIIR(), shift_hz, fs, 0.0)

function tick!(s::FreqShifterSSB, input::Float64)
    i, q = tick!(s.hilbert, input)
    output = i * cos(s.phase) + q * sin(s.phase)
    s.phase += 2π * s.shift_hz / s.sample_rate
    s.phase = mod(s.phase, 2π)
    output
end

function freq_shift_iir(x, shift_hz, fs)
    shifter = FreqShifterSSB(shift_hz, fs)
    [tick!(shifter, xi) for xi in x]
end

# Canonical RPM Sawtooth with Inharmonicity (from RPM_REFERENCE.md)
function rpm_saw(omega, beta, N; alpha=0.001, k=0.0)
    y = zeros(Float64, N)
    rms_sq = 0.5
    curv_rms = 0.01
    phase = 0.0

    for n in 2:N
        n1, n2, n3 = n-1, max(n-2, 1), max(n-3, 1)

        # Inharmonicity: curvature-based frequency modulation
        curv = y[n1] - 2*y[n2] + y[n3]
        curv_rms += 0.001 * (curv * curv - curv_rms)
        curv_norm = curv / sqrt(max(curv_rms, 1e-6))
        phase += omega * (1.0 + k * abs(tanh(curv_norm)))

        # Linear feedback (2-point TPT average)
        y_avg = 0.5 * (y[n1] + y[n2])
        y_sq = y[n1] * y[n1]
        rms_sq += alpha * (y_sq - rms_sq)
        rms = sqrt(max(rms_sq, 0.01))
        u = -beta * 0.5 * (y_avg / rms)

        y[n] = sin(phase + u)
    end
    y
end

# Canonical RPM Square with Inharmonicity (from RPM_REFERENCE.md)
function rpm_sqr(omega, beta, N; alpha=0.001, k=0.0)
    y = zeros(Float64, N)
    rms_sq = 0.5
    curv_rms = 0.01
    phase = 0.0

    for n in 2:N
        n1, n2, n3 = n-1, max(n-2, 1), max(n-3, 1)

        # Inharmonicity: curvature-based frequency modulation
        curv = y[n1] - 2*y[n2] + y[n3]
        curv_rms += 0.001 * (curv * curv - curv_rms)
        curv_norm = curv / sqrt(max(curv_rms, 1e-6))
        phase += omega * (1.0 + k * abs(tanh(curv_norm)))

        # Squared feedback (2-point TPT average)
        ysq_avg = 0.5 * (y[n1]^2 + y[n2]^2)
        rms_sq += alpha * (ysq_avg - rms_sq)
        u = -beta * (ysq_avg / max(rms_sq, 0.01) * 0.5 - 0.5)

        y[n] = sin(phase + u)
    end
    y
end

# FFT helper
function mag_spectrum(x)
    x = x .- mean(x)
    X = fft(x .* hann(length(x)))
    mag = abs.(X)[1:div(end,2)]
    mag ./ maximum(mag)
end

beta = 2.0
k_inharm = -0.3
C_saw = 0.07
C_sqr = 0.13

# Measure f0 from spectrum
function measure_f0(x, fs, target)
    spec = abs.(fft(x .* hann(length(x))))[1:div(end,2)]
    N = length(x)
    bin = round(Int, target / fs * N) + 1
    region = max(2,bin-30):min(length(spec)-1,bin+30)
    peak_bin = argmax(spec[region]) + first(region) - 1
    α = log(spec[peak_bin-1]); β = log(spec[peak_bin]); γ = log(spec[peak_bin+1])
    p = 0.5 * (α - γ) / (α - 2β + γ)
    (peak_bin - 1 + p) * fs / N
end

# ==== STEP 1: Synthesize waveforms ====
y_saw_harm_full = rpm_saw(omega, beta, N; k=0.0)
y_saw_inharm_full = rpm_saw(omega, beta, N; k=k_inharm)
y_sqr_harm_full = rpm_sqr(omega, beta, N; k=0.0)
y_sqr_inharm_full = rpm_sqr(omega, beta, N; k=k_inharm)

# ==== STEP 2: Apply IIR SSB frequency shift AFTER synthesis ====
# Predicted drift from formula
saw_correction = -f0 * k_inharm * C_saw
sqr_correction = -f0 * k_inharm * C_sqr

# Process full waveforms through frequency shifter
y_saw_comp_full = freq_shift_iir(y_saw_inharm_full, saw_correction, fs)
y_sqr_comp_full = freq_shift_iir(y_sqr_inharm_full, sqr_correction, fs)

# ==== STEP 3: Discard startup transient ====
y_saw_harm = y_saw_harm_full[discard:end]
y_saw_inharm = y_saw_inharm_full[discard:end]
y_saw_comp = y_saw_comp_full[discard:end]
y_sqr_harm = y_sqr_harm_full[discard:end]
y_sqr_inharm = y_sqr_inharm_full[discard:end]
y_sqr_comp = y_sqr_comp_full[discard:end]

# ==== Measure results ====
f0_saw_harm = measure_f0(y_saw_harm, fs, f0)
f0_saw_inharm = measure_f0(y_saw_inharm, fs, f0)
f0_saw_comp = measure_f0(y_saw_comp, fs, f0)
f0_sqr_harm = measure_f0(y_sqr_harm, fs, f0)
f0_sqr_inharm = measure_f0(y_sqr_inharm, fs, f0)
f0_sqr_comp = measure_f0(y_sqr_comp, fs, f0)

println("F0 Analysis (SSB shift applied AFTER synthesis)")
println("="^50)
println("Saw: harmonic=$(round(f0_saw_harm, digits=2)) Hz, inharm=$(round(f0_saw_inharm, digits=2)) Hz, comp=$(round(f0_saw_comp, digits=2)) Hz")
println("Sqr: harmonic=$(round(f0_sqr_harm, digits=2)) Hz, inharm=$(round(f0_sqr_inharm, digits=2)) Hz, comp=$(round(f0_sqr_comp, digits=2)) Hz")

# Compute spectra
spec_saw_harm = mag_spectrum(y_saw_harm)
spec_saw_inharm = mag_spectrum(y_saw_inharm)
spec_saw_comp = mag_spectrum(y_saw_comp)
spec_sqr_harm = mag_spectrum(y_sqr_harm)
spec_sqr_inharm = mag_spectrum(y_sqr_inharm)
spec_sqr_comp = mag_spectrum(y_sqr_comp)

freqs = fs .* (0:length(spec_saw_harm)-1) ./ length(y_saw_harm)

# Waveform plots
p1 = plot(y_saw_harm[1:500], label="harmonic", title="Sawtooth Waveform (beta=$beta)")
plot!(p1, y_saw_inharm[1:500], label="k=$k_inharm", alpha=0.7)

p2 = plot(y_sqr_harm[1:500], label="harmonic", title="Square Waveform (beta=$beta)")
plot!(p2, y_sqr_inharm[1:500], label="k=$k_inharm", alpha=0.7)

# Spectrum plots
p3 = plot(freqs, 20 .* log10.(spec_saw_harm .+ 1e-9),
    label="harmonic", title="Sawtooth Spectrum",
    xlim=(0, 3000), ylim=(-60, 0), xlabel="Hz", ylabel="dB")
plot!(p3, freqs, 20 .* log10.(spec_saw_inharm .+ 1e-9),
    label="k=$k_inharm", alpha=0.7)

p4 = plot(freqs, 20 .* log10.(spec_sqr_harm .+ 1e-9),
    label="harmonic", title="Square Spectrum",
    xlim=(0, 3000), ylim=(-60, 0), xlabel="Hz", ylabel="dB")
plot!(p4, freqs, 20 .* log10.(spec_sqr_inharm .+ 1e-9),
    label="k=$k_inharm", alpha=0.7)

final = plot(p1, p2, p3, p4, layout=(2,2), size=(1200, 800))

outfile = "rpm_inharmonic_saw_sqr.png"
savefig(final, outfile)
run(`open $outfile`)

println("\nImage saved: $outfile")
