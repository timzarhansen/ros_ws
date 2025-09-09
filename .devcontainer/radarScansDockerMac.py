from time import sleep

import yaml
# from numpy.f2py.crackfortran import endifs
import os
import docker
# from prompt_toolkit.utils import to_str


# docker run -t -i --rm --ipc=host -v /Users/timhansen/Documents/ros_ws/cache/humble/build:/home/tim-external/ros_ws/build \
#                                  -v /Users/timhansen/Documents/ros_ws/cache/humble/install:/home/tim-external/ros_ws/install \
#                                 -v /Users/timhansen/Documents/ros_ws/cache/humble/log:/home/tim-external/ros_ws/log \
#                                 -v /Users/timhansen/Documents/ros_ws/configFiles:/home/tim-external/ros_ws/configFiles \
#                                 -v /Users/timhansen/Documents/ros_ws/src:/home/tim-external/ros_ws/src \
#                                 -v /Users/timhansen/Documents/dataFolder:/home/tim-external/dataFolder \
# computationimageodometry








currentNumberScript = 1

# docker build -t computationimageodometry -f DockerfileBaseARM .
# computerPath = '/home/deeprobotics'
computerPath = '/Users/timhansen/Documents'

numberOfSkips = [1,2,3]

sizePixel = [0.25,0.5,0.75]
N = [512,256]
# N = [64]
def quoted_presenter(dumper, data):
    return dumper.represent_scalar('tag:yaml.org,2002:str', data, style='"')

yaml.add_representer(str, quoted_presenter)



client = docker.from_env()


for N_ in N:
    for numberOfSkips_ in numberOfSkips:
        for sizePixel_ in sizePixel:
            print("Configuring everything")


            bashFileNameHost = computerPath+'/ros_ws/src/fsregistration/pythonScripts/radarDataset/bashFilesDockerGenerated/myscript'+str(currentNumberScript)+'.sh'
            bashFileNameDocker = '/home/tim-external/ros_ws/src/fsregistration/pythonScripts/radarDataset/bashFilesDockerGenerated/myscript'+str(currentNumberScript)+'.sh'

            with open(bashFileNameHost, "w") as file:
                file.write("#!/bin/bash\n")
                file.write("export ROS_LOCALHOST_ONLY=1\n")
                file.write("export ROS_DOMAIN_ID="+str(currentNumberScript)+"\n")
                file.write("source /opt/ros/humble/setup.bash\n")
                file.write("source /home/tim-external/ros_ws/install/setup.bash\n")
                file.write("ros2 run fsregistration ros2ServiceRegistrationFS2D & >/dev/null 2>&1\n")
                file.write("\nsleep 10\n")
                file.write("cd /home/tim-external/ros_ws/src/fsregistration/pythonScripts/radarDataset \n")
                file.write(f"python3 testingSequence.py {str(N_)} 1 0.1 {str(sizePixel_)} {str(numberOfSkips_)} /home/tim-external/dataFolder/2019-01-10-14-36-48-radar-oxford-10k-partial2/radar")

            # Make the script executable

            os.chmod(bashFileNameHost, 0o755)
            print("created scripts and config files")
            #run bash script in docker
            while 1:
                try:
                    containers = client.containers.list()
                    total_memory_usage = sum(
                        stats['memory_stats']['usage'] / (1024 ** 3) for c in containers if
                        (stats := c.stats(stream=False)))
                    print("Memory usage is: ", total_memory_usage)

                    if (total_memory_usage < 100):
                        print("running container number: ", currentNumberScript)
                        container = client.containers.run(
                            image='computationimageodometry',
                            command=bashFileNameDocker,
                            volumes={
                                computerPath+'/ros_ws/cache/humble/build': {
                                    'bind': '/home/tim-external/ros_ws/build', 'mode': 'cached'},
                                computerPath+'/ros_ws/cache/humble/install': {
                                    'bind': '/home/tim-external/ros_ws/install', 'mode': 'cached'},
                                computerPath+'/ros_ws/cache/humble/log': {
                                    'bind': '/home/tim-external/ros_ws/log', 'mode': 'cached'},
                                computerPath+'/ros_ws/configFiles': {
                                    'bind': '/home/tim-external/ros_ws/configFiles', 'mode': 'cached'},
                                computerPath+'/ros_ws/src': {
                                    'bind': '/home/tim-external/ros_ws/src','mode': 'cached'},
                                computerPath+'/dataFolder': {
                                    'bind': '/home/tim-external/dataFolder','mode': 'cached'}
                            },
                            # network='devcontainer'+str(i)+'_net',
                            detach=True,
                            remove=True
                        )
                        sleep(30)
                        print("breaking out of while loop")
                        break
                except Exception as e:
                    print(e)
                    sleep(30)
                sleep(150)
            print("currentNumberScript done: ", currentNumberScript)
            currentNumberScript=currentNumberScript+1



