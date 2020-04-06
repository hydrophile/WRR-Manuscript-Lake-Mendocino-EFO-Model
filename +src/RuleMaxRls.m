classdef (Abstract) RuleMaxRls < handle
    % 6/10/2016
    % Super class for maximum release rules
    
    properties
        name                % Class name
        rlsFlood            % Flood release
    end
    
    methods
       % CLASS CONSTRUCTOR
        function this = RuleMaxRls(name)
            this.name = name;
        end
    end
    
    methods(Abstract)
        % GET MAX RELEASE
        getMaxRls(this,vars)
    end
    
end

