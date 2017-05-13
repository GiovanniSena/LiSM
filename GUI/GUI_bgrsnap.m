function [ output_args ] = GUI_bgrsnap( mainFig, sourceBtn )
%GUI_BGRSNAP Summary of this function goes here
%   Detailed explanation goes here

% Retrieving information required for function
    confData= getappdata(mainFig, 'confPar');
    video_obj= getappdata(mainFig, 'vidobj'); 
    video_src= getappdata(mainFig, 'videosrc');
    avg_sample= str2double(confData.user.avg_sample);
    DEBUG= confData.application.debug;
    
% Take a snap shot
    myPicture =  camera_snapshot_avg(video_obj, avg_sample);
    
% Calculate background
    [ T, BW, BWf, ttl_area ]= bgrcheck(myPicture);
    setappdata(mainFig, 'bgrarea', ttl_area);
    fprintf('Background objects area (%f) stored\n', ttl_area);

end
