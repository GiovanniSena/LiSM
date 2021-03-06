function [ output_args ] = GUI_peltierToggle( mainFig, state, power )
%%  GUI_PELTIERTOGGLE Toggle the Peltier cell on/off and sets the indicators accordingly.
%  
    myTemp= getappdata(mainFig, 'myTemp');
    PeltierInd= getappdata(mainFig, 'PeltierInd');
    if power>99
        power=99;
    end
    
    if (state)
        fprintf('PELTIER IS ON\n');
        set(PeltierInd, 'enable', 'off');
        %set(PeltierInd, 'String','<html>PELTIER<br>ON');
        set(PeltierInd, 'String',['<html>PELTIER<br>ON ' num2str(power) '%']);
        set(PeltierInd, 'backgroundcolor', 'green');
        if (power>98)
            tempHW_peltToggle(myTemp, 1);
        else
            tempHW_setPeltier(myTemp, power);
        end
    else
        fprintf('PELTIER IS OFF\n');
        set(PeltierInd, 'enable', 'off');
        set(PeltierInd, 'String','<html>PELTIER<br>OFF');
        set(PeltierInd, 'backgroundcolor', 'default');
        tempHW_peltToggle(myTemp, 0);
    end
end