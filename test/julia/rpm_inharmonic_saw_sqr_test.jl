using DSP, FFTW, Plots
gr()

fs = 48000.0
f0 = 220.0
omega = 2π * f0 / fs
N = 8192
discard = 2048

# Canonical RPM Sawtooth with Inharmonicity (from RPM_REFERENCE.md)
function rpm_saw(omega, beta, N; alpha=0.001, k=0.0)
    y = zeros(Float64, N)
    rms_sq = 0.5
    curv_rms = 0.01
    curv_avg = 0.0
    phase = 0.0

    for n in 2:N
        n1, n2, n3 = n-1, max(n-2, 1), max(n-3, 1)

        # Inharmonicity: curvature-based frequency modulation
        curv = y[n1] - 2*y[n2] + y[n3]
        curv_rms += 0.001 * (curv * curv - curv_rms)
        curv_norm = curv / sqrt(max(curv_rms, 1e-6))
        curv_contrib = abs(tanh(curv_norm))
        curv_avg += 0.001 * (curv_contrib - curv_avg)

        # Zero-mean phase modulation keeps fundamental at f0
        phase += omega * (1.0 + k * (curv_contrib - curv_avg))

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
    curv_avg = 0.0
    phase = 0.0

    for n in 2:N
        n1, n2, n3 = n-1, max(n-2, 1), max(n-3, 1)

        # Inharmonicity: curvature-based frequency modulation
        curv = y[n1] - 2*y[n2] + y[n3]
        curv_rms += 0.001 * (curv * curv - curv_rms)
        curv_norm = curv / sqrt(max(curv_rms, 1e-6))
        curv_contrib = abs(tanh(curv_norm))
        curv_avg += 0.001 * (curv_contrib - curv_avg)

        # Zero-mean phase modulation keeps fundamental at f0
        phase += omega * (1.0 + k * (curv_contrib - curv_avg))

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
    X = fft(x .* hann(length(x)))
    mag = abs.(X)[1:div(end,2)]
    mag ./ maximum(mag)
end

beta = 2.0
k_inharm = -0.3

y_saw_harm = rpm_saw(omega, beta, N; k=0.0)[discard:end]
y_saw_inharm = rpm_saw(omega, beta, N; k=k_inharm)[discard:end]
y_sqr_harm = rpm_sqr(omega, beta, N; k=0.0)[discard:end]
y_sqr_inharm = rpm_sqr(omega, beta, N; k=k_inharm)[discard:end]

spec_saw_harm = mag_spectrum(y_saw_harm)
spec_saw_inharm = mag_spectrum(y_saw_inharm)
spec_sqr_harm = mag_spectrum(y_sqr_harm)
spec_sqr_inharm = mag_spectrum(y_sqr_inharm)

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

outfile = tempname() * "_rpm_inharmonic_saw_sqr.png"
savefig(final, outfile)
run(`open $outfile`)

println("\nImage saved to: $outfile")
