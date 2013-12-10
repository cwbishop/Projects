function FFR_by_training_block_60single( fileName, xls_filename )
% This m-file will calculate phase coherence on blocks of 60 trials, from
% Project M's data.  This analysis is to be used as preliminary data to see
% if PC may be calculated over blocks of 60 single trials or 30
% concatenated files from a day's 360 stimulus presentations.
%
%  An Excel spreadsheet will be generated with the output.
%
% Data is trimmed to look at first 360 trials.
%
% Example: >> FFR_by_training_block_60concat ( 'm209500520ms', 'FFRspreadsheet.xls' )
%
% To run as a batch file, use with masterbatch.m
%  12/2009 C. Clinard
%% Load data and define Variables
load(fileName, ...
    'epoch_data_single', 'epoch_n', ... 
    'subject_id', 'age', 'stim_freq', 'bin', 'f', 't', 'fs')

block_length = 60;             % 60 trials per block for training
block_max = 6; % 360 epochs/60 epochs per block =  6 blocks, 3 if concatenated
% block_max = 5;                  % 1000/2 = 500; 500/100 = 5
block_index = 1;
max_num_sweeps = 360; %360 trials per day, will be halved when concatenated
epoch_n = max_num_sweeps;
epoch_data_single = epoch_data_single(:,1:epoch_n);
bin = round(bin/2);  % this is right for 500 Hz

NFFT = length(t); % This is 10402, half the resolution of concatenated FFT
f = fs/2 * linspace(0,1,NFFT/2);            % Frequency vector for plotting

% Trim to first 360 epochs and get FFT data
[sx, sy, epochs_concat] = get_fft_data(epoch_data_single, epoch_n, bin, NFFT);

ax = max(abs(sy))* 1.3;         % pad axes by 30% of max absolute value for debugging
output = 1;             % for tpt2

plot_width = 1.5;
figname = [fileName '--FFRx360 trials NOT concatenated'];
figure('Name', figname , 'Units', 'inches', 'Position', [ 1 1 10.5 6]);

%% calculations by training block length
indexes = [1 block_length];
    
for k = 1:block_max                       % for each block of responses
    x_position = (k*plot_width-.95)*1.1;  % x-coordiante for plotting
    
      % Partition sweeps by block
        sx_loop = sx(indexes(1):indexes(2));
        sy_loop = sy(indexes(1):indexes(2));
    
      % Calculate amplitude for subset of sweeps
    epochs4amp = epochs_concat(indexes(1):indexes(2));
    [amp, bin_nx, bin_snrdb, p_val_fft, Y ] = get_amp (epochs4amp, bin, NFFT);

    indexes = indexes + block_length;
    a(k) = axes('Units', 'inches', 'Position', [x_position 3.5 plot_width plot_width]);
    
      % plot FFR area
    bar(f, 2*abs(Y(1:NFFT/2)));                     % frequency on x-axis
     hold on
    stem(f(bin), amp, 'r','LineWidth', 1)           % highlight FFR bin
     hold off
    title('FFT');
    
   if k ==1;         ylabel('Amplitude (\muV)');        end
   
      % Calculate phase-based metrics
    [s1, s2, s3, phase_results, k, b] = tpt2_by_training_block(sx_loop, sy_loop, '' , ax, output, k, plot_width, x_position);
    
      % Annotate with results CHECK PVALUE OF MAGNITUDE SQUARED COHERENCE
    tb(k) = annotation('textbox', 'String',{ ['FFR Amp = ' (sprintf('%0.5f', amp)) ' \muV'], ...
        ['Noise \pm 5 Hz = ' (sprintf('%0.5f', bin_nx)) ' \muV'], ...
        ['SNR = ' (sprintf('%0.2f',bin_snrdb)) ' dB' ], ...
         (sprintf('p-value = %1.4f', p_val_fft)), ...
        '- - Phase Analysis - - ', ...
        sprintf('PC = %.4f, p = %.4f',phase_results.phase_coherence,phase_results.phase_coherence_pval),...
        sprintf('MSC = %.4f, p = %.4f',phase_results.msc,phase_results.ellipse_t2_pval) },...
        'Units', 'inches',...
        'Position',[x_position .9 plot_width plot_width/4], ...
        'FontSize', 8);

    if k ==1    % Set Axes Titles, e.g. sweeps 1 - 100
        title([ 'sweeps ' num2str(k) '-' num2str(100*k)]);
        ylabel('Amplitude (\muV)')
    else
        title([ 'sweeps ' num2str((100*(k-1))+1) '-' num2str(100*(k-1)+100)]);
    end
    
    % adjust block and subplot indices
    block_index = block_index+block_length; 
   
    if nargin > 1    % Make an Excel spreadsheet if its name is an agrument
        % Generate row-vector cell of strings for column headings
        headings = {'subject#'  , ...
            'age'               , ...
            'stim_frequency'    , ...
            'amplitude'         , ...
            'noise'             , ...
            'SNRdB'             , ...
            'SNR p-val'         , ...
            'ellipse_t2'        , ...
            'ellipse_t2_pval'   , ...
            'msc'               , ...
            'phase_coherence'   , ...
            'phase_coherence_pval'};%

        % Organize data for excel spreadsheet
        xls_data=[subject_id, age, stim_freq, amp, bin_nx, bin_snrdb, p_val_fft,...
            phase_results.ellipse_t2, phase_results.ellipse_t2_pval, ...
            phase_results.msc,...
            phase_results.phase_coherence, phase_results.phase_coherence_pval];

        save_xls(xls_filename, headings, xls_data, k)
    end
end

  % set axes properties
set(a(2:end), 'YTickLabel', '');
 
  ymax = get(a(:), 'YLim');
  for q = 1:length(ymax); ymax2(q) = ymax{q}(2); end 
  ymax2 = max(ymax2);
set(a(:),'TickLength', [0.02 0.02], 'Box', 'On',...
    'XLim', [stim_freq-100 stim_freq+100], ...
    'YLim', [0 ymax2]);

%% Annotate with subject/condition info
tb(k+1) = annotation('textbox','String',...
    {['Subject# ' num2str(subject_id) '           Age: ' num2str(age)],...
    ['Condition: ' fileName],...
    ['Stimulus Frequency = ' num2str(stim_freq) ' Hz']},...
    'Position',[0.02 0.95 0.425 0.05], 'Interpreter','none');

% add phase results from .mat file
load(fileName, 's1', 's2', 's3', 'amp', 'bin_nx', 'bin_snrdb', 'p_val_fft')
tb(k+2) = annotation('textbox', 'String'                    , ...
    {'Results from full data set:'                          , ...
    ['Amp = ' (sprintf('%0.5f', amp)) ' \muV']              , ...
    ['Noise \pm 5 Hz = ' (sprintf('%0.5f', bin_nx)) ' \muV'], ...
    ['SNR = ' (sprintf('%0.2f',bin_snrdb)) ' dB' ]          , ...
    (sprintf('p-value = %1.4f', p_val_fft))}                , ...
    'Units', 'inches'                                       , ...
    'Position', [5 5.85 2 0.05],    'FontSize', 8);                                   
    
% tb(k+3) = annotation('textbox', 'String'                    , ...
%     {'- - Phase Analysis - - '                               , ...
%     sprintf('PC = %.4f, p = %.4f',phase_results.phase_coherence,phase_results.phase_coherence_pval),...
%     sprintf('MSC = %.4f, p = %.4f',phase_results.msc,phase_results.ellipse_t2_pval)},...
%     'FontSize', 8                                           , ...
%     'Position', [5 5.85 2 0.05]);

tb(k+3) = annotation('textbox', 'String'                    , ...
    {'- - Phase Analysis - - ', s1, s2, s3}                 , ...
    'FontSize', 8                                           , ...
    'Units', 'inches'                                       , ...
    'Position', [6.75 5.85 3 .05]);
    
set(tb(:), 'FitHeightToText','off','LineStyle','none')

    saveas(gcf,['F:\Tera\Proj M\Adaptation\' figname ], 'fig')
    close; % closes figure
end

function [sx, sy, epochs_concat] = get_fft_data(epoch_data_single, epoch_n, bin, NFFT)
% DO NOT Concatenate consecutive sweeps, but get FFT data

%%%% Commented out for single epoch version of code %%%%
% k = 1:2:epoch_n;  % Concatenate
% epochs_concat = zeros(20804,500);
% for i = 1:epoch_n/2
% epochs_concat(:,i) = vertcat(epoch_data_single(:, k(i)), epoch_data_single(:,k(i)+1));
% end

% Still using epochs_concat variable to minimize code changes.
epochs_concat = epoch_data_single; 

  % Calculate FFT for each column of concatenated sweeps
h = waitbar(0,'FFTs being calcuated ...');
y = zeros(length(epochs_concat), epoch_n);
for i = 1:epoch_n;  %Calculate FFT for each column of concatenated sweeps
    y(:,i) = fft(epochs_concat(:,i),NFFT)/NFFT;
    waitbar(i/(epoch_n))
end
close(h) 

  % Get real and imaginary FFR data for each sweep:
complex = y(bin,1:epoch_n)';   % FFR data in complex form
sx = real(complex);   
sy = imag(complex); 
end

function [amp, bin_nx, bin_snrdb, p_val_fft, Y] = get_amp(epochs_concat, bin, NFFT)
Y = fft(epochs_concat,NFFT)/NFFT;

  % Calculate amplitude (in microvolts), noise, and SNRs
amp = 2 * abs(Y(bin));                  % amplitude at FFR's FFT bin
bin_low  = 2 * abs(Y(bin-5:bin-1))';    % the 2*abs keeps it in microvolts
bin_high = 2 * abs(Y(bin+1:bin+5))';
bin_nx = mean(vertcat(bin_low,bin_high)); % mean noise +/- 5 Hz
bin_snr = amp/bin_nx;                   % SNR re: plus and minus 5 Hz
bin_snrdb = 10 * log10(bin_snr);        % SNR in decibels
p_val_fft = 1 - fcdf(bin_snr,2,20);         % p-value for f-test

% ADD PLUS-MINUS NOISE ESTIMATE HERE
end