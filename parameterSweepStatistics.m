function [targetedVariance,targetedRs,randomRs] = parameterSweepStatistics(targetedSubjRinROIpair,randomSubjRinROIpair)
    
    % Average Rs across subjects
    targetedRs = nanmean(targetedSubjRinROIpair,2);
    randomRs = nanmean(randomSubjRinROIpair,2);

    targetedVariance = var(targetedSubjRinROIpair,0,2,'omitnan'); %Variance across subjects

end
