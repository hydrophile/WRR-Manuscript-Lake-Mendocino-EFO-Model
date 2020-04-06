classdef (Abstract) RuleRampRate < handle
    % Super class for ramp rate rules
    
    properties
        name            % Class name
        rlsRamp         % Simulated release after ramping (cfs)
    end
    
    methods
       % CLASS CONSTRUCTOR
        function this = RuleRampRate(name)
            this.name = name;
        end
    end
    
    methods(Abstract)
        getAjustedRls(this,vars)
    end
    
end

