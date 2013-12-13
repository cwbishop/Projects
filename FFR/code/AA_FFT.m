function AA_FFT(ERPF, FRANGE, NSEM, BINS, PLEV)
%% DESCRIPTION:
%
%   Basic function to compute an FFT based on ERP data structure for AA02
%   (and others).
%
% INPUT:
%
%   ERPF:   cell, each element is the full path to an ERP file
%   PLEV:   plot level setting (1=just group, 2=group and subject data;
%           default=1)
%   NSEM:   integer, number of SEMs to include in error bars (default=0)
%   BINS:   integer index, BINS to include in the analysis
%
% OUTPUT:
%
%   XXX
%
% Christopher W. Bishop
%   University of Washington
%   12/13

%% PARAMETERS
if ~exist('PLEV', 'var') || isempty(PLEV), PLEV=1; end
if ~exist('NSEM', 'var') || isempty(NSEM), NSEM=0; end % 0 by default

% PRE-STIM FFT STUFF
pY=[];
pA=[]; % One sided amplitude data
pP=[]; % Phase data
    
% POST-STIM FFT STUFF
Y=[]; % Complex FFT 
A=[]; % One sided amplitude data
P=[]; % Phase data

%% REPEAT FOR ALL SUBJECTS
for s=1:length(ERPF)
    
    %% FILE PARTS OF INPUT FILE
    [pathstr,name,ext]= fileparts(deblank(ERPF{s}));

    %% LOAD THE ERPFILE
    ERP=pop_loaderp('filename', [name ext], 'filepath', pathstr); 

    %% WHICH BINS TO ANALYZE?
    %   Analyze all bins by default
    if ~exist('BINS', 'var') || isempty(BINS)
        BINS=1:size(ERP.bindata,3); 
    end % if ~exist('BINS ...
    
    %% EXTRACT PARAMETERS
    LABELS={ERP.bindescr{BINS}}; % bin description labels
    BLMASK=1:find(ERP.times<0,1,'last'); % base line time mask
    TMASK=find(ERP.times>=0, 1, 'first'):length(ERP.times); % post-stim mask.
        
    DATA=squeeze(ERP.bindata(:,:,:)); 
    FS=ERP.srate; 

    %% COMPUTE FFT FOR EACH DATA BIN    
    for i=1:length(BINS)
    
        % Compute pre-stim data (useful for noise sanity check...I think)
        L=length(BLMASK);
        NFFT = L; % Not doing next power of 2 in an attempt to get coherent sampling
        pf = FS/2*linspace(0,1,NFFT/2+1);
        
        y=DATA(BLMASK,BINS(i)); 
        
        pY(:,i,s)=fft(y,NFFT)/NFFT; % Normalize FFT output
        pA(:,i,s)=2*abs(pY(1:NFFT/2+1,i,s)); 
        pP(:,i,s)=angle(pY(1:NFFT/2+1,i,s)); % Need to check this.    
        
        % Compute post-stim data
        L=length(TMASK);
        NFFT=L;
%         NFFT = 2^nextpow2(L); % Next power of 2 from length of y
        f = FS/2*linspace(0,1,NFFT/2+1);
        
        y=DATA(TMASK,i); 
        
        Y(:,i,s)=fft(y,NFFT)/NFFT;
        A(:,i,s)=2*abs(Y(1:NFFT/2+1,i,s)); 
        P(:,i,s)=angle(Y(1:NFFT/2+1,i,s)); % Need to check this.  

    end % for i=1:size(DATA,3)
    
    %% PLOT SUBJECT DATA
    %   Only plot if user specifies this level of detail
    if PLEV==2
        figure, hold on
        % plot pre-stim data
    %     plot(pf, squeeze(pA(:,:,s)), '--', 'linewidth', 1);
    
        % plot post-stim data
        plot(f, squeeze(A(:,:,s)), '-', 'linewidth', 2);
        title('Single-Sided Amplitude Spectrum of y(t)')
        xlabel('Frequency (Hz)')
        ylabel('|Y(f)|')    
        legend(LABELS); 
        title([ERP.erpname ' | Bins: [' num2str(BINS) ']']); % set ERPNAME as title
    
        % Set domain if user specifies it
        if exist('FRANGE', 'var')
            xlim(FRANGE);
        end %
    end % if PLEV==2
    
end % for s=1:size(SID,1)

%% PLOT SUBJECT MEAN
if PLEV>0
    % Figure
    figure, hold on
    
    % Get color and style defs for each bin
    [colorDef, styleDef]=erplab_linespec(size(A,2)); 
        
    %% PLOT ERROR
    %   Plotted first for ease of legend labeling
    for i=1:size(A,2) % for each bin we are plotting
        
        tdata=squeeze(A(:,i,:)); 
        
        % Compute +/-1 SEM
        U=mean(tdata,2) + std(tdata,0,2)./sqrt(size(tdata,2)).*NSEM; 
        L=mean(tdata,2) - std(tdata,0,2)./sqrt(size(tdata,2)).*NSEM; 
        
        % Plotting SEM when NSEM=0 causes some graphical issues and very
        % slow performance. 
        if NSEM~=0
            ciplot(L, U, f, colorDef{i}, 0.15); 
        end 
        
    end % for i=1:size(A,2)    
        
    for i=1:size(A,2) % for each bin we are plotting        
        tdata=mean(squeeze(A(:,i,:)),2); 
        plot(f, tdata, 'Color', colorDef{i}, 'LineStyle', styleDef{i}, 'linewidth', 1.5);
    end % for i=1:size(A,2)
    
    xlabel('Frequency (Hz)')
    ylabel('|Y(f)|')
    legend(LABELS); 
    title(['N=' num2str(length(ERPF)) ' | Bins: [' num2str(BINS) ']']); 

    % Set domain if user specifies it
    if exist('FRANGE', 'var')
        xlim(FRANGE);
    end %
    
end % if PLEV>0