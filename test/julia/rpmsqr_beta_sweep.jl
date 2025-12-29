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
betas = [0.0, -0.5, -1.0, -1.5, -2.0, -3.0, -4.0, -6.0, -8.0]

# -----------------------------
# Squaring function
# -----------------------------
sqr(y) = y * y

# -----------------------------
# 4-point sqr→avg (DC-compensated)
# -----------------------------
function rpmsqr_tpt_4pt(omega, beta, N)
    y = zeros(Float64, N)
    phase = 0.0
    for n in 2:N
        phase += omega
        n1, n2, n3, n4 = n-1, max(n-2, 1), max(n-3, 1), max(n-4, 1)
        u = beta * (sqr(y[n1]) + sqr(y[n2]) + sqr(y[n3]) + sqr(y[n4]) - 2.0) / 4.0  # DC-compensated
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
# Generate signals for each beta
# -----------------------------
signals = Dict{Float64, Vector{Float64}}()
spectra = Dict{Float64, Vector{Float64}}()

for β in betas
    y = rpmsqr_tpt_4pt(omega, β, N)
    y = y[discard:end]
    signals[β] = y
    spectra[β] = mag_spectrum(y)
end

freqs = fs .* (0:length(spectra[betas[1]])-1) ./ length(signals[betas[1]])

# -----------------------------
# Plots
# -----------------------------

# Find zero-crossings for fine alignment
zero_crossings = Dict{Float64, Int}()
for β in betas
    zero_crossings[β] = find_zero_crossing(signals[β])
end
ref_zc = zero_crossings[0.0]
plot_length = 1000

# Time-domain plot (DC-compensated + zero-crossing aligned)
# Draw higher |β| first so they appear behind
p1 = plot(
    title="RPM Squaring 4-point sqr→avg DC-compensated (f0 = $f0 Hz)",
    xlabel="Samples",
    ylabel="Amplitude",
    legend=:outerright
)
for β in reverse(betas)
    offset = zero_crossings[β] - ref_zc
    start_idx = max(1, 1 + offset)
    end_idx = min(length(signals[β]), plot_length + offset)
    plot!(p1, signals[β][start_idx:end_idx], label="β=$β", alpha=0.8)
end

# Frequency-domain plot
p2 = plot(
    title="Magnitude Spectrum",
    xlabel="Frequency (Hz)",
    ylabel="Magnitude (dB)",
    xlim=(0, 5000),
    ylim=(-80, 0),
    legend=:outerright
)
for β in reverse(betas)
    plot!(p2, freqs, 20 .* log10.(spectra[β] .+ 1e-9), label="β=$β", alpha=0.8)
end

final_plot = plot(p1, p2, layout=(2,1), size=(1200,800))

# Save and open
outfile = tempname() * "_rpmsqr_beta_sweep.png"
savefig(final_plot, outfile)
run(`open $outfile`)

println("\nRPM Squaring Beta Sweep (4-point sqr→avg)")
println("==========================================")
println("f0 = $f0 Hz")
println("β values: $betas")
println("")
println("Usage: julia rpmsqr_beta_sweep.jl [f0]")
println("       julia rpmsqr_beta_sweep.jl 440")
println("")
println("Image saved to: $outfile")
