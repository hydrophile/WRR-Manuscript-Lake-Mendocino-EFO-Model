classdef Constants < handle
    %UNTITLED Summary of this class goes here
    %   Detailed explanation goes here
    
    % TODO: Mabe vDateYear and nTs should be included here instead of
    % passed independently to classes.  Maybe include vData as well.  Might
    % want to try this to see if it improve performance.
    % TODO: Add the beginning datenumber that way you can just add t.step
    % to that to calculate vDate when needed and not have to pass it with
    % the time variables.
    properties
%         name
        vDate
        vDateYear
        nTimeSteps
        dT
        cfs2af
        af2cfs
    end
    
    methods
        % CLASS CONSTRUCTOR
        function this = setConstants(this,vDate,vDateYear)
            this.vDate = vDate;
            this.vDateYear = vDateYear;
            [this.nTimeSteps,~] = size(this.vDate);
            this.dT = datenum([vDate(2,:)]) - datenum([vDate(1,:)]);
             % Create unit conversion variables
            this.cfs2af = 1.98347109902*this.dT;
            this.af2cfs = 0.50416666040/this.dT;
        end
    end
    
end

