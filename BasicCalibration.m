function BasicCalibration
  [BaseImage,calib_path] = uigetfile('../*.jpg');  % Pick the starting image from Cam 1 with the computers GUI
  
  Main = load('MainData.mat'); % Load Main Global Variables
  CamNum = Main.NumberOfCamerasInArray;
  XWidth = Main.ResolutionOfCameraWidth;
  YHeight = Main.ResolutionOfCameraHeight;
  
  % Preallocate the memory for your image array
  ImgStore = zeros(480,XWidth,1,CamNum,'uint8');
  % CamOff = [0 -6 -11 -19 -16 -12];  % Frame Offset(not syncronized)
  CamData = zeros(4,2,CamNum); % Make Array to store X and Y points
  n = 1;  % Point # Counter
  j = 1;  % Camera # Counter
  ZoomOn = false; % Zoom Tool variable

  hFigure = figure('Position',[0 0 XWidth+80 480],...    % Create a figure window
                   'MenuBar','none','Renderer','OpenGL','Resize','off');
  axes('Parent', hFigure, 'Units', 'pixels',...   % Create the Axis to display images on
                  'Position', [1 1 XWidth YHeight], 'Visible', 'off');
  zoombutton = uicontrol('Style','pushbutton','String','<html>ZOOM TOOL<br>IS OFF',...  % Create the Zoom Button
                         'Position',[XWidth+2 280 80 60],'FontSize',10,...
                         'HorizontalAlignment','center','Callback',@zoom_tool);
  
  pause(0.001); % Needs to pause the code real quick so it can build the figure
  
  for i = 1:CamNum
    frmNum = sscanf(BaseImage,'camera1_frame%f'); % Scan fro what frame it was that you choose for your base image
      
    % Load the base Frame from every Camera(i) to pick calibration points
    Filename = sprintf([calib_path 'camera%d_frame%06d.jpg'],i,frmNum);
    %Filename = sprintf([calib_path 'camera%d_frame%06d.jpg'],i,frmNum+CamOff(i));
    ImgStore(:,:,:,i) = imread(Filename);  % Store your images to be grabbed later
  end
  disp('Images Loaded')

  h = imshow(ImgStore(:,:,:,1),'Parent',gca); % show Base Image on the current axis
  set(h,'buttondownfcn', @plot_point) %refresh function to wait for click
  
  function plot_point(gcbo,hObject,eventdata) % Executes on every click(Only when zoom is off)
    hold on % Freezes the axis so you can plot more than one thing (picture and crosshair)
    Point(:,:,n) = get(gca,'CurrentPoint'); % Store the X & Y coords for where you just clicked
    plot(Point(1,1,n),Point(1,2,n),'y+','LineWidth',2,'MarkerSize',10) % plot that point you just clicked
    CamData(n,:,j) = Point(1,1:2,n); % take that point and store for calibration
    n = n + 1; % You clicked so add one to the point counter to let it know what point we are on
    hold off % Update the axis for new stuff
    if n == 5 % if we clicked 4 times
      hold off 
      pause(0.250) % Lets user see where they clicked instead of automatically changing on 4th click
      j = j + 1; % Next image
      n = 1; % Reset point counter
      if j <= CamNum % If we still havent seen every camera or are on the last one 
        h = imshow(ImgStore(:,:,:,j),'Parent',gca); % Show the new image
        set(h,'buttondownfcn', @plot_point)
      else  % If we have captured the points for each camera
        close all 
        assignin('base', 'var1', CamData) % Save the variable to the workspace incase it doesn't save to file
        [FileName,PathName] = uiputfile('/home/fip2012/Documents/MATLAB/','Save As'); % open GUI to select save location
        save([PathName FileName],'CamData');
        clear all
        disp('Image Calibration Data Aquired and Saved');  
      end
    end
  end

  function zoom_tool(hObject,eventdata) % Click it once to turn in on, click it again to turn it off
      if ZoomOn == false
        zoom on
        ZoomOn = true;
        set(zoombutton,'String','<html>ZOOM TOOL<br>IS ON');
      else
        zoom off
        ZoomOn = false;
        set(zoombutton,'String','<html>ZOOM TOOL<br>IS OFF');
      end
  end
end


