function ImgArray = LoadImages(FrmStart, FrmEnd)

  Main = load('MainData.mat'); % Load Main Global Variables
  CamNum = Main.NumberOfCamerasInArray;
  XWidth = Main.ResolutionOfCameraWidth;
  YHeight = Main.ResolutionOfCameraHeight;

  % Preallocate the memory for your image array
  ImgArray = zeros(YHeight,XWidth,1,CamNum,FrmEnd-FrmStart+1,'uint8');
  
  % Creates a Loading screen while the images are read from the hard drive
  loadscreen = figure('Position',[600 400 150 25],'MenuBar','none','Resize','off');
  uicontrol('Parent',loadscreen,'Style','text','String','Loading Images...',...
            'Position',[1 1 150 25],'HorizontalAlignment','Left','FontSize',13);
  pause(0.001); % Needs to pause the code real quick so it can build the figure
  
  % Only Used for Unsynced Data 
  %CamFlash = [209 193 189 177 172 166]; % Name of Frame from each camera that contains the flash
  %CamOff = zeros(1);  % Number of frames offset from name of frame number for 6 cameras
  %for i = 1:CamNum
  %  CamOff(i) = CamFlash(i) - min(CamFlash);
  %end
  
  for z = FrmStart:FrmEnd    
    for i = 1:CamNum
      % Load every Frame(z) from every Camera(i)
      Filename = sprintf('/home/share/camera%d_frame%06d.jpg',i,z);
      %Filename = sprintf('home/share/camera%d_frame%06d.jpg',i,z+CamOff(i));
      ImgArray(:,:,:,i,z) = imread(Filename);
    end   
  end
  close % Closes the loading screen
end