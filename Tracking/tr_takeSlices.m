function [myStack]= tr_takeSlices(mainFig, fileName )
%%  TR_TAKESLICES Take N pictures, moving Sy after each snap, and save them to file
%    
%   NB the stack will be 1040x1392xn matrix, with root horizontal and tip to the righ 
 
%   v. 161027
    fprintf('EXECUTING SCAN\n');

%   Retrieve hardware handles
    confData= getappdata(mainFig, 'confPar');
    video_obj= getappdata(mainFig, 'vidobj'); 
    video_src= getappdata(mainFig, 'videosrc');
    DEBUG= confData.application.debug;
    AFInd = getappdata(mainFig, 'AFInd');
 
%   Retrieve area of objects in background image
    bgrarea= getappdata(mainFig, 'bgrarea');
    
%   Retrieve parameters, including N slices and step
    nSlices= str2double(confData.user.nimages); % images in a stack
    camerax= str2double(confData.camera.camerax); %1040px = our X dimension
    cameray= str2double(confData.camera.cameray); %1392px = our Z dimension
    ySpacing= str2double(confData.user.yspacing); %spacing between images of stack
    afinterval= str2double(confData.user.afinterval); % every 'afinterval' slices, the AF step is executed 
    afspacing= str2double(confData.user.afspacing); % step for af spacing
    saveDir= confData.application.savedir; %save folder
    avg_sample= str2double(confData.user.avg_sample); % numbers of samples to use for averagins images
    safeDist= str2double(confData.motor.safedist_fy); %safety parameter
    camadjustroot=str2num(confData.user.f_fystep); % retrieves necessary delta F as function of delta Y, calibrated with a H2B:YFP root
    camadjustbgrd=str2num(confData.user.f_fdeltay); % retrieves necessary delta F as function of delta Y, calibrated with fluorescent beads
    logDir= confData.application.logdir;
 
%   Preallocate empty stack
    myStack= uint16(zeros(camerax, cameray, nSlices)); % camerax=#rows=1040; cameray=1392=#columns : it is ready to image a horizontal root (that is what the camera sees)
    
%   Read current coordinates (Sy and F)
    motorHandles = getappdata(mainFig, 'actxHnd');
    currentF= HW_getPos(motorHandles(5));
    currentY= HW_getPos(motorHandles(2));
    if (DEBUG)
        myMsg= ['Current Positions: Y= ' num2str(currentY) '; F= ' num2str(currentF)];
        disp(myMsg);
    end
    
%   Check distance cuvette-objective
    finalY= (nSlices-1)*ySpacing + currentY;
    if ((finalY + currentF) >= safeDist)
        myError = ['Current parameters will bring objective in collision with cuvette. Move stages or change settings (tab AUTO, CONFIG), then try again. Final delta= ' num2str(-finalF-currentY+safeDist, '%0.3f') '; Current delta= ' num2str(-currentF - currentY +safeDist, '%0.3f')];
        errordlg(myError);
    else
        
%   Read file name
        if isempty(fileName)
            myError= ('Please specify a file name');
            errordlg(myError);
        else
            if (DEBUG)
                myMsg= ['N_slices= ' num2str(nSlices) '; Spacing= ' num2str(ySpacing) '; AvgFrames=' num2str(avg_sample)];
                disp(myMsg);
                myMsg= [fprintf('Stack will be saved in: \n') saveDir fileName];
                disp(myMsg);
            end
    %   Read current coordinates, write them to file together with stack name
            motorLabArray = ['X', 'Y', 'Z', 'C', 'Focus', 'Shutter']; 
            logString = '';
            for i= 1:5
                pos = HW_getPos(motorHandles(i));
                logString= [logString   motorLabArray(i)   '= '  num2str(pos, '%02.4f') '; ']; 
            end
            fileSplit= strsplit(fileName, '.');
            initialPosY= HW_getPos(motorHandles(2));  %isn't it the same as CurrentY above?
            initialPosF= HW_getPos(motorHandles(5));   %isn't it the same as CurrentF above?
            
            fileNameLog = [char(fileSplit(1)) '.txt']; % NAME OF THE LOG FILE
            logString = [fileName '; ' logString, 'YSpacing= ' num2str(ySpacing, '%01.4f') ' mm \n']; 
            if(DEBUG) disp(logString); end
            fid = fopen([logDir fileNameLog], 'a+');
            fprintf(fid, logString);
            fclose(fid);
            
    %   Loop and take snapshots
            for i=1:nSlices
                fprintf('TAKING IMAGE %d OF %d\n', i, nSlices);
                
            %   Check if slice contains root or if empty
                myPicture =  camera_snapshot_avg(video_obj, avg_sample);
                [ T, BW, BWf, ttl_area ]= bgrcheck(myPicture);
                bwName=strrep(fileName, '.tif', '_bw.tif');
                bwPath=strcat( saveDir , '\_bw\', bwName);
                TIFF_write(myPicture, bwPath);  % <<<<< JUST CHECKING THE IMAGE USED FOR AREA CALCULATION
                fprintf('n largest objects area (%f) stored\n', ttl_area);
                
                if ttl_area>(2*bgrarea) % if root is in the field (i.e. if total area of segmented blobs is large enough)            
                    if i>1  %skip first slice because didn't move cuvette, yet
                    HW_moveRelative(motorHandles(5), camadjustroot*ySpacing); % move F using calibration in tissue 
                    end
                    % Autofocus
                    if (afinterval~=0) 
                            if mod(i,afinterval)==0 % autofocus every "afinterval" images                       
                                set(AFInd, 'string', '<html>AF<br>ON');
                                set(AFInd, 'backgroundcolor', 'green'); 
                                tr_autofocus(afspacing,  motorHandles(5), video_obj); % actual AF routine
                                set(AFInd, 'string', '<html>AF<br>OFF');
                                set(AFInd, 'backgroundcolor', 'default');
                            end
                    end
                else % if root is not in the field
                    if i>1  %skip first slice because didn't move cuvette, yet
                    HW_moveRelative(motorHandles(5), camadjustbgrd*ySpacing); % move F using calibration in liquid 
                    end
                end
                
            %   Take snapshot and append it to the stack image
                myPicture =  camera_snapshot_avg(video_obj, avg_sample);
                myStack(:,:,i)= myPicture;
                TIFF_write(myPicture, [saveDir fileName]);
                pause(video_src.Exposure); %wait until exposure is completed
               
            %   Move to next slice
                HW_moveRelative(motorHandles(2), ySpacing);       
            end
            
        %   Return Sy and F to initial positions
            HW_moveAbsolute(motorHandles(2), initialPosY);
            HW_moveAbsolute(motorHandles(5), initialPosF);
        
        end %refers to if line50
    end %refers to if line 44
    fprintf('SCAN FINISHED\n');
end

