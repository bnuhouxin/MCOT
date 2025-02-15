function [optimalDV, optimalFD, optimalPCT, minMSE] = mCotWrapper(workingDir, varargin)
    %UNTITLED Summary of this function goes here
    %   Detailed explanation goes here
    
    %% Create the working directory file heirarchy.
    
    if ~exist(workingDir, 'dir')
        mkdir(workingDir);
    end
    
    
    if ~exist([workingDir filesep 'InternalData'], 'dir')
        mkdir([workingDir filesep 'InternalData']);
    end
    
    if ~exist([workingDir filesep 'Outputs'], 'dir')
        mkdir([workingDir filesep 'Outputs']);
    end
    
    if ~exist([workingDir filesep 'Logs'], 'dir')
        mkdir([workingDir filesep 'Logs']);
    end
    
    
    
    %% Argument decoding and Variable Instantiation

    pathToDefaults = which('mcotDefaults.mat');
    load(pathToDefaults, 'filterCutoffs','format','minSecDataNeeded', 'nTrim', 'numOfSecToTrim','useGSR');
    imageSpace = '';
    
    
    continueBool = false;
    parameterSweepFileName = [workingDir filesep 'InternalData' filesep 'paramSweep.mat'];
    
    
    for curArg = 1:2:length(varargin)
        switch(lower(string(varargin{curArg})))
            case "motionparameters"
                MPs = varargin{curArg + 1};
            case "tr"
                TR = varargin{curArg + 1};
            case "filenamematrix"
                filenameMatrix = varargin{curArg + 1};
            case "maskmatrix"
                maskMatrix = varargin{curArg + 1};
            case "usegsr"
                useGSR = varargin{curArg + 1};
            case "ntrim"
                nTrim = varargin{curArg + 1};
            case "format"
                format = varargin{curArg + 1};
            case "continue"
                continueBool = true;
            case "sourcedirectory"
                sourceDir = varargin{curArg + 1};
            case "runnames"
                rsfcTaskNames = varargin{curArg + 1};
            case "minimumsecondsdataperrun"
                minSecDataNeeded = varargin{curArg + 1};
            case "filtercutoffs"
                filterCutoffs = varargin{curArg + 1};
            case "sectrimpostbpf"
                numOfSecToTrim = varargin{curArg + 1};
            case "imagespace"
                imageSpace = varargin{curArg + 1};
            otherwise
                error("Unrecognized input argument")
        end
    end
    
    disp('Read all arguments')
    
    
    
    %% Argument Validation --------- this needs another pass after the GUI is made so we can nail down variables
    
    if continueBool
        try
            load([workingDir filesep 'InternalData' filesep 'currentStep.mat'], 'subjExtractedCompleted', 'paramSweepCompleted', 'maxBiasCompleted');
            load([workingDir filesep 'InternalData' filesep 'inputFlags.mat'], 'varargin');
            % Reparse input values from previous run
            for curArg = 1:2:length(varargin)
                switch(lower(string(varargin{curArg})))
                    case "motionparameters"
                        MPs = varargin{curArg + 1};
                    case "tr"
                        TR = varargin{curArg + 1};
                    case "filenamematrix"
                        filenameMatrix = varargin{curArg + 1};
                    case "maskmatrix"
                        maskMatrix = varargin{curArg + 1};
                    case "usegsr"
                        useGSR = varargin{curArg + 1};
                    case "ntrim"
                        nTrim = varargin{curArg + 1};
                    case "format"
                        format = varargin{curArg + 1};
                    case "continue"
                        continueBool = true;
                    case "sourcedirectory"
                        sourceDir = varargin{curArg + 1};
                    case "runnames"
                        rsfcTaskNames = varargin{curArg + 1};
                    case "minimumsecondsdataperrun"
                        minSecDataNeeded = varargin{curArg + 1};
                    case "filtercutoffs"
                        filterCutoffs = varargin{curArg + 1};
                    case "sectrimpostbpf"
                        numOfSecToTrim = varargin{curArg + 1};
                    case "imagespace"
                        imageSpace = varargin{curArg + 1};
                    otherwise
                        error("Unrecognized input argument")
                end
            end
            continueBool = true;
        catch
            threshOptLog([workingDir filesep 'Logs' filsep 'log.txt'],'Tried to continue from previous run but no data found.');
            error('Tried to continue from previous run but no data found.')
        end
    else
        subjExtractedCompleted = false;
        paramSweepCompleted = false;
        maxBiasCompleted = false;
        save([workingDir filesep 'InternalData' filesep 'inputFlags.mat'], 'varargin','-v7.3','-nocompression');
        save([workingDir filesep 'InternalData' filesep 'currentStep.mat'], 'subjExtractedCompleted', 'paramSweepCompleted', 'maxBiasCompleted', '-v7.3', '-nocompression');
    end
    
    if ~subjExtractedCompleted

        %% Parse supported directory structures to automatically calc filenames, masks, and MPs
        
        if ~strcmp(format, 'custom')
            [filenameMatrix, maskMatrix, MPs] = filenameParser(sourceDir, format, rsfcTaskNames, workingDir, imageSpace);
            disp('Files parsed')
        end
        
        
        
        %% Validate Provided Files
        
        if ~fileValidator(filenameMatrix, maskMatrix)
            threshOptLog([workingDir filesep 'Logs' filesep 'log.txt'], 'Filename or Mask Files could not be validated.  Make sure all files provided are nifti format, uncompressed, and accessible to the current user');
            error('Filename or Mask Files could not be validated.  Make sure all files provided are nifti format, uncompressed, and accessible to the current user')
        end
        
        disp('Files validated')
        
        
        
        %% SubjExtractedTimeSeries

        subjExtractedTimeSeries = subjExtractedTimeSeriesMaker(filenameMatrix, TR, nTrim, MPs, maskMatrix, workingDir, continueBool, filterCutoffs);
        subjExtractedCompleted = true;
        save([workingDir filesep 'InternalData' filesep 'currentStep.mat'], 'subjExtractedCompleted', '-append', '-nocompression');
        disp('Filtering completed. ROI Time Series calculated.')
    else
        load([workingDir filesep 'InternalData' filesep 'subjExtractedTimeSeries.mat'], 'subjExtractedTimeSeries');
        disp('Loaded subjExtractedTimeSeries.mat')
    end
    
    
    
    %% Parameter sweep
    if ~paramSweepCompleted
        [totalNumFrames,targetedVariance,targetedRs,randomRs,FDcutoffs,gevDVcutoffs, totalNumFramesRemaining] = mseParameterSweep(subjExtractedTimeSeries,useGSR,parameterSweepFileName, TR, continueBool, numOfSecToTrim, minSecDataNeeded);
        paramSweepCompleted = true;
        save([workingDir filesep 'InternalData' filesep 'paramSweepReturns.mat'], 'totalNumFrames','targetedVariance','targetedRs','randomRs','FDcutoffs','gevDVcutoffs', 'totalNumFramesRemaining', '-v7.3', '-nocompression');
        save([workingDir filesep 'InternalData' filesep 'currentStep.mat'], 'paramSweepCompleted', '-append', '-nocompression');
        disp('Parameter sweep completed')
    else
        load([workingDir filesep 'InternalData' filesep 'paramSweepReturns.mat']);
        disp('Loaded paramSweepReturns.mat')
    end
    
    %% Max bias calculation
    if ~(maxBiasCompleted && paramSweepCompleted)
        maxBias = maxBiasCalculation(totalNumFramesRemaining,totalNumFrames,targetedRs,randomRs);
        maxBiasCompleted = true;
        save([workingDir filesep 'InternalData' filesep 'maxBias.mat'], 'maxBias', '-v7.3', '-nocompression');
        save([workingDir filesep 'InternalData' filesep 'currentStep.mat'], 'maxBiasCompleted', '-append','-nocompression'); %Always save current step AFTER saving data
        disp('Max bias calculation completed')
    else
        load([workingDir filesep 'InternalData' filesep 'maxBias.mat']);
        disp('Loaded maxBias.mat')
    end
    
    %% MSE calculation and MSE optimum
    [optimalDV, optimalFD, optimalPCT, minMSE] = mseCalculation(maxBias,totalNumFrames,targetedVariance,targetedRs,randomRs,FDcutoffs,gevDVcutoffs, totalNumFramesRemaining,[workingDir filesep 'InternalData']);
    
    disp('MSE calculation completed. saving outputs')
    
    save([workingDir filesep 'Outputs' filesep 'Outputs.mat'], 'optimalDV', 'optimalFD', 'optimalPCT', 'minMSE','-v7.3','-nocompression');
    disp('outputs saved - returning')
    
end


