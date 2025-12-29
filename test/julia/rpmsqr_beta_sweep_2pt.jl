using DSP, FFTW, Plots
gr()

# -----------------------------
# Global parameters
# -----------------------------
fs      = 48000.0
f0      = length(ARGS) >= 1 ? parse(Float64, ARGS[1]) : 220.0
omega   = 2π * f0 / fs
N       = 8192
discard = 2048

# Beta values to compare
betas = [0.0, -0.25, -0.5, -0.75, -1.0, -1.25, -1.5, -1.75, -2.0]

# -----------------------------
# Squaring function
# -----------------------------
sqr(y) = y * y

# -----------------------------
# Method 1: Adaptive DC tracking
# -----------------------------
function rpmsqr_adaptive(omega, beta, N; alpha=0.001)
    y = zeros(Float64, N)
    dc = 0.5
    phase = 0.0
    for n in 2:N
        phase += omega
        n1, n2 = n-1, max(n-2, 1)
        ysq_avg = 0.5 * (sqr(y[n1]) + sqr(y[n2]))
        dc += alpha * (ysq_avg - dc)
        u = beta * (ysq_avg - dc)
        y[n] = sin(phase + u)
    end
    y
end

# -----------------------------
# Method 2: Power-normalized (RMS tracking)
# -----------------------------
function rpmsqr_power_norm(omega, beta, N; alpha=0.001)
    y = zeros(Float64, N)
    rms_sq = 0.5  # initial estimate of E[y²]
    phase = 0.0
    for n in 2:N
        phase += omega
        n1, n2 = n-1, max(n-2, 1)
        ysq_avg = 0.5 * (sqr(y[n1]) + sqr(y[n2]))
        rms_sq += alpha * (ysq_avg - rms_sq)
        # normalize so ysq_avg/rms_sq has mean 1, then subtract 0.5
        u = beta * (ysq_avg / max(rms_sq, 0.01) * 0.5 - 0.5)
        y[n] = sin(phase + u)
    end
    y
end

# -----------------------------
# FFT helper
# -----------------------------
function mag_spectrum(x)
    X = fft(x .* hann(length(x)))
    mag = abs.(X)[1:div(end,2)]
    mag ./ maximum(mag)
end

# Find first positive zero-crossing
function find_zero_crossing(y)
    for i in 2:length(y)
        if y[i-1] <= 0 && y[i] > 0
            return i
        end
    end
    return 1
end

# -----------------------------
# Generate signals for each method and beta
# -----------------------------
methods = [
    ("Adaptive DC", rpmsqr_adaptive),
    ("Power-normalized", rpmsqr_power_norm)
]

all_signals = Dict{String, Dict{Float64, Vector{Float64}}}()
all_spectra = Dict{String, Dict{Float64, Vector{Float64}}}()

for (name, func) in methods
    signals = Dict{Float64, Vector{Float64}}()
    spectra = Dict{Float64, Vector{Float64}}()
    for β in betas
        y = func(omega, β, N)
        y = y[discard:end]
        signals[β] = y
        spectra[β] = mag_spectrum(y)
    end
    all_signals[name] = signals
    all_spectra[name] = spectra
end

freqs = fs .* (0:length(all_spectra["Adaptive DC"][betas[1]])-1) ./ length(all_signals["Adaptive DC"][betas[1]])
plot_length = 1000

# -----------------------------
# Create comparison plots
# -----------------------------
plots_time = []
plots_freq = []

for (name, _) in methods
    signals = all_signals[name]
    spectra = all_spectra[name]

    # Find zero-crossings for alignment
    zero_crossings = Dict{Float64, Int}()
    for β in betas
        zero_crossings[β] = find_zero_crossing(signals[β])
    end
    ref_zc = zero_crossings[0.0]

    # Time-domain plot
    p_time = plot(
        title="$name (f0 = $f0 Hz)",
        xlabel="Samples",
        ylabel="Amplitude",
        legend=:outerright
    )
    for β in reverse(betas)
        offset = zero_crossings[β] - ref_zc
        start_idx = max(1, 1 + offset)
        end_idx = min(length(signals[β]), plot_length + offset)
        plot!(p_time, signals[β][start_idx:end_idx], label="β=$β", alpha=0.8)
    end
    push!(plots_time, p_time)

    # Frequency-domain plot
    p_freq = plot(
        title="$name Spectrum",
        xlabel="Frequency (Hz)",
        ylabel="Magnitude (dB)",
        xlim=(0, 5000),
        ylim=(-80, 0),
        legend=:outerright
    )
    for β in reverse(betas)
        plot!(p_freq, freqs, 20 .* log10.(spectra[β] .+ 1e-9), label="β=$β", alpha=0.8)
    end
    push!(plots_freq, p_freq)
end

# Combine: 2 time-domain on top, 2 frequency on bottom
final_plot = plot(
    plots_time[1], plots_time[2],
    plots_freq[1], plots_freq[2],
    layout=(2, 2),
    size=(1400, 900)
)

# Save and open
outfile = tempname() * "_rpmsqr_dc_comparison.png"
savefig(final_plot, outfile)
run(`open $outfile`)

println("\nRPM Squaring DC Compensation Comparison")
println("========================================")
println("f0 = $f0 Hz")
println("β values: $betas")
println("Methods: Adaptive DC, Power-normalized")
println("")
println("Usage: julia rpmsqr_beta_sweep_2pt.jl [f0]")
println("       julia rpmsqr_beta_sweep_2pt.jl 440")
println("")
println("Image saved to: $outfile")
