using DSP, FFTW, Plots
gr()

fs = 48000.0
f0 = 110.0
omega = 2π * f0 / fs
N = 8192
discard = 2048

# Canonical RPM Sawtooth (from rpm_beta_sweep_2pt.jl)
# Linear feedback, RMS-normalized, scaled by 0.5
function rpm_saw(omega, beta, N; alpha=0.001)
    y = zeros(Float64, N)
    rms_sq = 0.5
    phase = 0.0
    for n in 2:N
        phase += omega
        n1, n2 = n-1, max(n-2, 1)
        y_avg = 0.5 * (y[n1] + y[n2])
        y_sq = y[n1] * y[n1]
        rms_sq += alpha * (y_sq - rms_sq)
        rms = sqrt(max(rms_sq, 0.01))
        u = -beta * 0.5 * (y_avg / rms)
        y[n] = sin(phase + u)
    end
    y
end

# Canonical RPM Square (from rpmsqr_beta_sweep_2pt.jl)
# Squared feedback, power-normalized
function rpm_sqr(omega, beta, N; alpha=0.001)
    y = zeros(Float64, N)
    rms_sq = 0.5
    phase = 0.0
    for n in 2:N
        phase += omega
        n1, n2 = n-1, max(n-2, 1)
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

# Test with negative beta (canonical)
betas = [-1.0, -1.5, -2.0]

println("Testing RPM Saw vs Square (canonical implementations)")
println("f0 = $f0 Hz\n")

for beta in betas
    y_saw = rpm_saw(omega, beta, N)[discard:end]
    y_sqr = rpm_sqr(omega, beta, N)[discard:end]

    spec_saw = mag_spectrum(y_saw)
    spec_sqr = mag_spectrum(y_sqr)

    saw_harmonics = sum(20 .* log10.(spec_saw .+ 1e-9) .> -40)
    sqr_harmonics = sum(20 .* log10.(spec_sqr .+ 1e-9) .> -40)

    println("beta = $beta: saw harmonics = $saw_harmonics, sqr harmonics = $sqr_harmonics")
end

# Generate plots for beta = 2.0
beta = 2.0
y_saw = rpm_saw(omega, beta, N)[discard:end]
y_sqr = rpm_sqr(omega, beta, N)[discard:end]

spec_saw = mag_spectrum(y_saw)
spec_sqr = mag_spectrum(y_sqr)
freqs = fs .* (0:length(spec_saw)-1) ./ length(y_saw)

p1 = plot(y_saw[1:500], title="Sawtooth (beta=$beta)", ylabel="Amplitude", label="")
p2 = plot(y_sqr[1:500], title="Square (beta=$beta)", ylabel="Amplitude", label="")

p3 = plot(freqs, 20 .* log10.(spec_saw .+ 1e-9),
    title="Saw Spectrum", xlim=(0, 3000), ylim=(-60, 0),
    xlabel="Hz", ylabel="dB", label="")

p4 = plot(freqs, 20 .* log10.(spec_sqr .+ 1e-9),
    title="Sqr Spectrum", xlim=(0, 3000), ylim=(-60, 0),
    xlabel="Hz", ylabel="dB", label="")

final = plot(p1, p2, p3, p4, layout=(2,2), size=(1200, 800))

outfile = tempname() * "_rpm_saw_sqr.png"
savefig(final, outfile)
run(`open $outfile`)

println("\nImage saved to: $outfile")
