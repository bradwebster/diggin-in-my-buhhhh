%% MAE 315 - DSP Lab - Group 3
% Time domain, frequency domain and Nyquist diagram for one experiment.
% Set MATLAB's Current Folder to the "DSP Data" folder before running.
% Each experiment needs two files:  <exp>_..._dat.txt  and  <exp>_..._fft.txt
clear; clc; close all;

%% Choose the experiment - type ONLY the experiment number, e.g. 4-2-03
% (or type PSM for the partial sum reconstruction)
expNum = strtrim(strrep(strrep(input('Enter experiment number (e.g. 4-1-11b) or PSM: ', 's'), '"', ''), '''', ''));

%% Partial Sum Reconstruction (user typed PSM)
% y(t) = a0 + sum of b_n*sin(w_n*t), from the hand calculations
if strcmpi(expNum, 'PSM')
    a0 = 0.533;                              % constant (DC) term [V]
    bn = [3.84 1.27 0.75 0.52 0.39];         % sine coefficients [V]
    wn = [1400 4200 7000 9800 12600];        % angular frequencies [rad/s]

    T  = 2*pi / wn(1);                       % period of the fundamental [s]
    t  = linspace(0, 2*T, 2000).';           % two periods
    terms = bn .* sin(t * wn);               % each column = one sine term
    S     = a0 + cumsum(terms, 2);           % column n = partial sum of n terms

    % Print to the command window
    fprintf('Partial sum reconstruction:  y(t) = %.3f', a0);
    fprintf(' + %.2f sin(%gt)', [bn; wn]);
    fprintf('\nPeriod of fundamental = %.4f ms\n', T*1e3);
    Coefficients = table((1:numel(bn)).', bn.', wn.', wn.'/(2*pi), ...
        'VariableNames', {'n', 'b_n_V', 'w_n_rad_per_s', 'f_n_Hz'})

    figure('Name', 'Partial Sum Reconstruction', 'Color', 'w', ...
        'Units', 'normalized', 'Position', [0.1 0.05 0.7 0.85]);
    colors = lines(numel(bn));

    % Top: each individual term and the full sum
    subplot(2, 1, 1); hold on; grid on; box on;
    plot(t*1e3, a0*ones(size(t)), 'k:', 'LineWidth', 1);
    for n = 1:numel(bn)
        plot(t*1e3, terms(:, n), 'Color', colors(n, :), 'LineWidth', 1);
    end
    plot(t*1e3, S(:, end), 'Color', [0.7 0 0], 'LineWidth', 2.5);
    legend([{sprintf('a_0 = %.3f', a0)}, ...
        arrayfun(@(n) sprintf('Term %d: %.2f sin(%gt)', n, bn(n), wn(n)), 1:numel(bn), 'UniformOutput', false), ...
        {sprintf('Sum of all %d terms', numel(bn))}], 'Location', 'eastoutside');
    xlim([0 2*T*1e3]); ylim(1.15*[min(terms(:)) max(S(:))] + [-0.1 0.1]);
    xlabel('Time (ms)'); ylabel('Voltage (V)');
    title('Individual Fourier Series Terms and Their Sum');

    % Bottom: partial sums for n = 1, 2, ..., N terms
    subplot(2, 1, 2); hold on; grid on; box on;
    for n = 1:numel(bn)
        plot(t*1e3, S(:, n), 'Color', colors(n, :), 'LineWidth', 1 + 0.4*n);
    end
    legend(arrayfun(@(n) sprintf('n = %d term(s)', n), 1:numel(bn), 'UniformOutput', false), 'Location', 'eastoutside');
    xlim([0 2*T*1e3]); ylim([min(S(:)) max(S(:))] + [-0.2 0.2]*(max(S(:)) - min(S(:))));
    xlabel('Time (ms)'); ylabel('Voltage (V)');
    title('Partial Sum Reconstruction for Increasing Number of Terms n');
    return
end

% Find the data folder: Current Folder, then Downloads\DSP Group 3 Data,
% and if neither has .txt files, ask the user to pick the folder.
dataDir = pwd;
downloadsDir = fullfile(getenv('USERPROFILE'), 'Downloads', 'DSP Group 3 Data');
if isempty(dir(fullfile(dataDir, '**', '*.txt'))) && isfolder(downloadsDir)
    dataDir = downloadsDir;
end
if isempty(dir(fullfile(dataDir, '**', '*.txt')))
    dataDir = uigetdir(pwd, 'Select the "DSP Data" folder');
    if isequal(dataDir, 0), error('No data folder selected.'); end
end
fprintf('Data folder    : %s\n', dataDir);

% All .txt files in the data folder and its subfolders
files = [dir(fullfile(dataDir, '*.txt')); dir(fullfile(dataDir, '**', '*.txt'))];
[~, iu] = unique(strcat({files.folder}, filesep, {files.name}));  files = files(iu);
names = {files.name};

% Files that start with the experiment number followed by "_", "-", space...
isExp = ~cellfun(@isempty, regexpi(names, ['^' regexptranslate('escape', expNum) '[^a-z0-9]'], 'once'));
isDat = isExp & ~cellfun(@isempty, regexpi(names, 'dat(\.txt)+$', 'once'));
isFft = isExp & ~cellfun(@isempty, regexpi(names, 'fft(\.txt)+$', 'once'));

if ~any(isDat) || ~any(isFft)
    expList = unique(regexp(names, '^[^_ ]+', 'match', 'once'));
    error(['Could not find both the dat.txt and fft.txt files for "%s" in\n  %s\n' ...
           'Experiment numbers found here: %s'], expNum, dataDir, strjoin(expList, ', '));
end
datFile = files(find(isDat, 1));
fftFile = files(find(isFft, 1));
fprintf('Time data file : %s\nFFT data file  : %s\n', datFile.name, fftFile.name);

%% Load data (column 1 = time or frequency, column 2 = voltage)
dat = readmatrix(fullfile(datFile.folder, datFile.name));  dat = dat(all(~isnan(dat), 2), :);
fftData = readmatrix(fullfile(fftFile.folder, fftFile.name));  fftData = fftData(all(~isnan(fftData), 2), :);
if size(dat, 1) == 2,     dat = dat.';         end   % data saved as rows
if size(fftData, 1) == 2, fftData = fftData.'; end

t    = dat(:, 1);      V    = dat(:, 2);
freq = fftData(:, 1);  Vfft = fftData(:, 2);

fs = 1 / mean(diff(t));    % sampling frequency [Hz]
fN = fs / 2;               % Nyquist frequency [Hz]
df = mean(diff(freq));     % frequency resolution [Hz]

%% Prominent peaks in the FFT (local maxima >= 10% of largest, no DC)
isPk = [false; Vfft(2:end-1) > Vfft(1:end-2) & Vfft(2:end-1) >= Vfft(3:end); false];
isPk(freq < 2*df) = false;
isPk = isPk & Vfft >= 0.10 * max(Vfft(freq >= 2*df));
pkIdx = find(isPk);
[~, order] = sort(Vfft(pkIdx), 'descend');
pkIdx  = pkIdx(order(1:min(6, numel(order))));
pkFreq = freq(pkIdx);  pkAmp = Vfft(pkIdx);

%% Actual signal frequency: from the file name (e.g. "sine-700Hz", "24kHz")
tok = regexpi(datFile.name, '(\d+\.?\d*)\s*(k?)hz', 'tokens', 'once');
if ~isempty(tok)
    f0 = str2double(tok{1}) * 1000^strcmpi(tok{2}, 'k');
else
    f0 = pkFreq(1);   % no frequency in the name: use the biggest peak
end

% Folding: apparent frequency of any actual frequency f
fold = @(f) abs(f - fs*round(f/fs));

% Actual frequency behind each measured peak = the lowest harmonic of f0
% that folds onto it (the fundamental for a sine, odd harmonics for square)
pkActual = pkFreq;
for p = 1:numel(pkFreq)
    n = find(abs(fold((1:100)*f0) - pkFreq(p)) <= 3*df, 1);
    if ~isempty(n), pkActual(p) = n*f0; end
end

%% Print data to the command window
fprintf('\nExperiment %s\n', expNum);
fprintf('Sampling frequency fs  = %.1f Hz\n', fs);
fprintf('Nyquist frequency fs/2 = %.1f Hz\n', fN);
fprintf('Input signal frequency = %.1f Hz -> appears at %.1f Hz\n', f0, fold(f0));
Peaks = table(pkFreq, pkAmp, pkActual, 'VariableNames', ...
    {'Measured_Freq_Hz', 'Amplitude_V', 'Actual_Freq_Hz'})
TimeData = table(t, V, 'VariableNames', {'Time_s', 'Voltage_V'})
FFTData  = table(freq, Vfft, 'VariableNames', {'Frequency_Hz', 'Voltage_V'})

%% Figure
figure('Name', expNum, 'Color', 'w', 'Units', 'normalized', 'Position', [0.05 0.05 0.9 0.85]);

% ---- 1) Time domain: show about 5 periods of the signal as it appears ----
subplot(2, 2, 1);
plot(t, V, 'LineWidth', 1.2); grid on;
tShow = min(t(end) - t(1), 5 / max(pkFreq(1), 1/(t(end)-t(1))));
xlim([t(1) t(1) + tShow]);
ylim([min(V) max(V)] + [-0.1 0.1]*max(max(V) - min(V), eps));
xlabel('Time (s)'); ylabel('Voltage (V)');
title(['Time Domain - ' expNum], 'Interpreter', 'none');

% ---- 2) Frequency domain: full spectrum ----
subplot(2, 2, 3);
plot(freq, Vfft, 'LineWidth', 1.2); hold on; grid on;
plot(pkFreq, pkAmp, 'rv', 'MarkerFaceColor', 'r');
text(pkFreq, pkAmp, compose('  %.0f Hz', pkFreq), 'VerticalAlignment', 'bottom');
xlim([0 max(freq)]); ylim([0 1.15*max(Vfft)]);
xlabel('Frequency (Hz)'); ylabel('Voltage (V)');
title(['Frequency Domain - ' expNum], 'Interpreter', 'none');

% ---- 3) Nyquist diagram ----
% The zig-zag runs 0 -> fs/2 along each level and folds back on the
% diagonals. x = apparent frequency, level = how many times fs it has passed.
subplot(2, 2, [2 4]); hold on;
nSeg = max(3, ceil(max(pkActual) / fN) + 1);
nSeg = nSeg + (mod(nSeg, 2) == 0);                 % end on a flat line
yPath = @(f) floor(floor(f/fN)/2) + mod(floor(f/fN), 2) .* (f/fN - floor(f/fN));
fLine = linspace(0, nSeg*fN, 4000);
plot(fold(fLine)/1e3, yPath(fLine), 'LineWidth', 2.5, 'Color', [0 0.45 0.74]);

for k = 0:nSeg                                      % corner labels
    fc = k*fN;
    if mod(k, 2) == 0, ha = 'right'; dx = -0.03; else, ha = 'left'; dx = 0.03; end
    text(fold(fc)/1e3 + dx*fN/1e3, yPath(fc), sprintf('%g kHz', fc/1e3), ...
        'HorizontalAlignment', ha);
end

for p = 1:numel(pkActual)                           % peaks
    fa = pkActual(p);  xa = fold(fa)/1e3;  ya = yPath(fa);
    plot(xa, ya, 'r*', 'MarkerSize', 12, 'LineWidth', 1.5);
    text(xa, ya + 0.12, sprintf('%.0f Hz', fa), 'Rotation', 45, 'Color', 'r');
    if ya > 1e-6                                   % aliased: show where it lands
        plot([xa xa], [ya 0], 'r--', 'LineWidth', 1);
        plot(xa, 0, 'ko', 'MarkerFaceColor', 'y', 'MarkerSize', 8);
        text(xa, -0.15, sprintf('appears at %.0f Hz', fold(fa)), ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'top');
    end
end
xlim([-0.25 1.25] * fN/1e3); ylim([-0.5, floor(nSeg/2) + 0.5]);
set(gca, 'YTick', []); box on; grid on;
xlabel('Apparent (Observed) Frequency (kHz)');
title(sprintf('Nyquist Diagram - %s  (fs = %g kHz)', expNum, fs/1e3), 'Interpreter', 'none');
