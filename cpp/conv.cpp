#include <iostream>
#include <fstream>
#include <cstring>

using namespace std;

int main()
{
    fstream fFile("./maps.txt", ios::in);
    if(!fFile.is_open())
    {
        cout << "missing maplist -> \"maps.txt\"" << endl;

        exit(0);
    }

    fstream fFile2("./downloadmaps.txt", ios::out | ios::binary);

    string map;
    char buffer[512];
    while(getline(fFile, map))
    {
        sprintf(buffer, "wget2 https://surfdl.net/csgo/maps/%s.bsp.bz2\r\n", map.c_str());
        fFile2.write(buffer, strlen(buffer));
    }

    fFile.close();
    fFile2.close();

    return 0;
}